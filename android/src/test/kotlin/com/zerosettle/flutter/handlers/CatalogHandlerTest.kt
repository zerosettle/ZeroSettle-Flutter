package com.zerosettle.flutter.handlers

import android.app.Activity
import android.content.Context
import com.google.common.truth.Truth.assertThat
import com.zerosettle.sdk.ZeroSettle
import com.zerosettle.sdk.models.Entitlement
import com.zerosettle.sdk.models.EntitlementSource
import com.zerosettle.sdk.models.Product
import com.zerosettle.sdk.models.ProductCatalog
import com.zerosettle.sdk.models.ProductType
import com.zerosettle.sdk.models.ZeroSettleError
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkObject
import io.mockk.slot
import io.mockk.unmockkObject
import io.mockk.verify
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

/**
 * Unit tests for [CatalogHandler].
 *
 * Mirrors [IdentityHandlerTest]'s setup — `mockkObject(ZeroSettle)`,
 * `UnconfinedTestDispatcher` so `scope.launch { ... }` resolves
 * synchronously, all SDK boundaries stubbed.
 *
 * Wire-shape claims under test:
 *   - `getProducts` / `getEntitlements` emit a `List<Map<...>>`, not a
 *     wrapper map — Dart's parsers cast to `List`.
 *   - `product` emits `null` when the id isn't cached (Optional semantics).
 *   - `hasActiveEntitlement` is synchronous (no coroutine fence required).
 *   - `fetchProducts` emits the catalog's `ProductCatalog.toFlutterMap()`
 *     (the wrapper `{"products":[...]}`).
 *   - `restoreEntitlements` emits the entitlement list directly (matches
 *     iOS line 584).
 *   - SDK `Result.failure(ZeroSettleError.*)` maps to the typed error code
 *     via the shared `sendError` extension defined alongside F8.
 */
@OptIn(ExperimentalCoroutinesApi::class)
@RunWith(RobolectricTestRunner::class)
class CatalogHandlerTest {

    private val scope = CoroutineScope(SupervisorJob() + UnconfinedTestDispatcher())
    private val appContext: Context = mockk(relaxed = true)
    private val activity: Activity = mockk(relaxed = true)
    private lateinit var handler: CatalogHandler

    @Before
    fun setUp() {
        mockkObject(ZeroSettle)
        // Default StateFlow stubs — individual tests override.
        every { ZeroSettle.products } returns MutableStateFlow(emptyList())
        every { ZeroSettle.entitlements } returns MutableStateFlow(emptyList())
        // product() and hasActiveEntitlement() fall through to default behavior
        // unless individual tests stub.

        val deps = HandlerDependencies(
            scope = scope,
            activityProvider = { activity },
            applicationContextProvider = { appContext },
        )
        handler = CatalogHandler(deps)
    }

    @After
    fun tearDown() {
        unmockkObject(ZeroSettle)
        scope.cancel()
    }

    private fun call(method: String, args: Map<String, Any?>? = null) = MethodCall(method, args)
    private fun newResult() = mockk<MethodChannel.Result>(relaxed = true)

    private fun newProduct(id: String = "com.foo.bar") = Product(
        id = id,
        displayName = "Bar",
        productDescription = "A product",
        type = ProductType.NON_CONSUMABLE,
        syncedToAppStoreConnect = true,
    )

    private fun newEntitlement(
        id: String = "ent-1",
        productId: String = "com.foo.bar",
        isActive: Boolean = true,
    ) = Entitlement(
        id = id,
        productId = productId,
        source = EntitlementSource.WEB_CHECKOUT,
        isActive = isActive,
        // Constructor uses `_statusRaw` (the private backing field for
        // `statusRaw` get-only property) — see Entitlement.kt:35.
        _statusRaw = "active",
        willRenew = true,
        isTrial = false,
        purchasedAt = "2026-01-01T00:00:00Z",
    )

    // ─── handle() routing ───────────────────────────────────────────────

    @Test
    fun `handle returns false for unknown method`() {
        val result = newResult()
        val consumed = handler.handle(call("definitelyNotMine"), result)
        assertThat(consumed).isFalse()
        verify(exactly = 0) { result.success(any()) }
        verify(exactly = 0) { result.error(any(), any(), any()) }
    }

    @Test
    fun `handle returns true for each owned method`() {
        // Stub product() to avoid a real call.
        every { ZeroSettle.product(any()) } returns null
        every { ZeroSettle.hasActiveEntitlement(any()) } returns false
        listOf(
            "fetchProducts",
            "getProducts",
            "product" to mapOf("productId" to "x"),
            "hasActiveEntitlement" to mapOf("productId" to "x"),
            "getEntitlements",
            "restoreEntitlements",
        ).forEach { entry ->
            val (method, args) = when (entry) {
                is String -> entry to null
                is Pair<*, *> -> {
                    @Suppress("UNCHECKED_CAST")
                    (entry.first as String) to (entry.second as Map<String, Any?>?)
                }
                else -> error("unexpected")
            }
            // restoreEntitlements / fetchProducts need a coroutine-side stub
            // to not throw before the test assertion. Keep them inert.
            coEvery { ZeroSettle.fetchProducts() } returns Result.failure(
                ZeroSettleError.UserNotIdentified,
            )
            coEvery { ZeroSettle.restoreEntitlements() } returns Result.failure(
                ZeroSettleError.UserNotIdentified,
            )
            val consumed = handler.handle(call(method, args), newResult())
            assertThat(consumed).isTrue()
        }
    }

    // ─── fetchProducts ──────────────────────────────────────────────────

    @Test
    fun `fetchProducts returns catalog wrapper map on success`() = runTest {
        val catalog = ProductCatalog(products = listOf(newProduct(id = "com.app.coins")))
        coEvery { ZeroSettle.fetchProducts() } returns Result.success(catalog)
        val mapSlot = slot<Map<String, Any?>>()
        val result = newResult()
        every { result.success(capture(mapSlot)) } answers { }

        handler.handle(call("fetchProducts", mapOf("userId" to "u1")), result)

        // iOS shape: `{"products":[...]}` — the ProductCatalog wrapper.
        coVerify { ZeroSettle.fetchProducts() }
        @Suppress("UNCHECKED_CAST")
        val products = mapSlot.captured["products"] as List<Map<String, Any?>>
        assertThat(products).hasSize(1)
        assertThat(products[0]["id"]).isEqualTo("com.app.coins")
    }

    @Test
    fun `fetchProducts maps UserNotIdentified to user_not_identified`() = runTest {
        coEvery { ZeroSettle.fetchProducts() } returns Result.failure(
            ZeroSettleError.UserNotIdentified,
        )
        val result = newResult()

        handler.handle(call("fetchProducts"), result)

        verify { result.error(eq("user_not_identified"), any(), null) }
    }

    @Test
    fun `fetchProducts maps SDK throw to sdk_error`() = runTest {
        coEvery { ZeroSettle.fetchProducts() } throws RuntimeException("boom")
        val result = newResult()

        handler.handle(call("fetchProducts"), result)

        verify { result.error("sdk_error", "boom", null) }
    }

    @Test
    fun `fetchProducts ignores userId arg (Android SDK reads from currentUserId)`() = runTest {
        coEvery { ZeroSettle.fetchProducts() } returns Result.success(
            ProductCatalog(products = emptyList()),
        )
        val result = newResult()

        handler.handle(call("fetchProducts", mapOf("userId" to "u-explicit")), result)

        // SDK call took no args — the wire-level `userId` is ignored.
        coVerify(exactly = 1) { ZeroSettle.fetchProducts() }
        verify { result.success(mapOf("products" to emptyList<Any?>())) }
    }

    // ─── getProducts ────────────────────────────────────────────────────

    @Test
    fun `getProducts returns empty list when cache is empty`() {
        every { ZeroSettle.products } returns MutableStateFlow(emptyList())
        val result = newResult()

        handler.handle(call("getProducts"), result)

        verify { result.success(emptyList<Map<String, Any?>>()) }
    }

    @Test
    fun `getProducts returns wire-encoded list of products`() {
        every { ZeroSettle.products } returns MutableStateFlow(
            listOf(newProduct(id = "com.app.coins"), newProduct(id = "com.app.gems")),
        )
        val listSlot = slot<List<Map<String, Any?>>>()
        val result = newResult()
        every { result.success(capture(listSlot)) } answers { }

        handler.handle(call("getProducts"), result)

        assertThat(listSlot.captured).hasSize(2)
        assertThat(listSlot.captured[0]["id"]).isEqualTo("com.app.coins")
        assertThat(listSlot.captured[1]["id"]).isEqualTo("com.app.gems")
    }

    // ─── product (single lookup) ────────────────────────────────────────

    @Test
    fun `product returns wire-encoded map when id found`() {
        every { ZeroSettle.product("com.app.coins") } returns newProduct(id = "com.app.coins")
        val mapSlot = slot<Map<String, Any?>>()
        val result = newResult()
        every { result.success(capture(mapSlot)) } answers { }

        handler.handle(call("product", mapOf("productId" to "com.app.coins")), result)

        verify { ZeroSettle.product("com.app.coins") }
        assertThat(mapSlot.captured["id"]).isEqualTo("com.app.coins")
    }

    @Test
    fun `product returns null when id not found`() {
        every { ZeroSettle.product("missing") } returns null
        val result = newResult()

        handler.handle(call("product", mapOf("productId" to "missing")), result)

        verify { result.success(null) }
    }

    @Test
    fun `product errors on missing productId arg`() {
        val result = newResult()

        handler.handle(call("product", emptyMap<String, Any?>()), result)

        verify { result.error("INVALID_ARGUMENTS", "productId is required", null) }
        verify(exactly = 0) { ZeroSettle.product(any()) }
    }

    // ─── hasActiveEntitlement ───────────────────────────────────────────

    @Test
    fun `hasActiveEntitlement returns true when SDK says yes`() {
        every { ZeroSettle.hasActiveEntitlement("com.app.coins") } returns true
        val result = newResult()

        handler.handle(call("hasActiveEntitlement", mapOf("productId" to "com.app.coins")), result)

        verify { result.success(true) }
    }

    @Test
    fun `hasActiveEntitlement returns false when SDK says no`() {
        every { ZeroSettle.hasActiveEntitlement("com.app.coins") } returns false
        val result = newResult()

        handler.handle(call("hasActiveEntitlement", mapOf("productId" to "com.app.coins")), result)

        verify { result.success(false) }
    }

    @Test
    fun `hasActiveEntitlement errors on missing productId`() {
        val result = newResult()

        handler.handle(call("hasActiveEntitlement", emptyMap<String, Any?>()), result)

        verify { result.error("INVALID_ARGUMENTS", "productId is required", null) }
        verify(exactly = 0) { ZeroSettle.hasActiveEntitlement(any()) }
    }

    // ─── getEntitlements ────────────────────────────────────────────────

    @Test
    fun `getEntitlements returns empty list when cache is empty`() {
        every { ZeroSettle.entitlements } returns MutableStateFlow(emptyList())
        val result = newResult()

        handler.handle(call("getEntitlements"), result)

        verify { result.success(emptyList<Map<String, Any?>>()) }
    }

    @Test
    fun `getEntitlements returns wire-encoded list`() {
        every { ZeroSettle.entitlements } returns MutableStateFlow(
            listOf(newEntitlement(id = "ent-1"), newEntitlement(id = "ent-2")),
        )
        val listSlot = slot<List<Map<String, Any?>>>()
        val result = newResult()
        every { result.success(capture(listSlot)) } answers { }

        handler.handle(call("getEntitlements"), result)

        assertThat(listSlot.captured).hasSize(2)
        assertThat(listSlot.captured[0]["id"]).isEqualTo("ent-1")
        assertThat(listSlot.captured[1]["id"]).isEqualTo("ent-2")
    }

    // ─── restoreEntitlements ────────────────────────────────────────────

    @Test
    fun `restoreEntitlements returns wire-encoded list on success`() = runTest {
        coEvery { ZeroSettle.restoreEntitlements() } returns Result.success(
            listOf(newEntitlement(id = "ent-1"), newEntitlement(id = "ent-2")),
        )
        val listSlot = slot<List<Map<String, Any?>>>()
        val result = newResult()
        every { result.success(capture(listSlot)) } answers { }

        handler.handle(call("restoreEntitlements", mapOf("userId" to "u1")), result)

        coVerify { ZeroSettle.restoreEntitlements() }
        assertThat(listSlot.captured).hasSize(2)
        assertThat(listSlot.captured[0]["id"]).isEqualTo("ent-1")
    }

    @Test
    fun `restoreEntitlements works without userId arg (current-user variant)`() = runTest {
        coEvery { ZeroSettle.restoreEntitlements() } returns Result.success(emptyList())
        val result = newResult()

        handler.handle(call("restoreEntitlements"), result)

        coVerify { ZeroSettle.restoreEntitlements() }
        verify { result.success(emptyList<Map<String, Any?>>()) }
    }

    @Test
    fun `restoreEntitlements maps UserNotIdentified to user_not_identified`() = runTest {
        coEvery { ZeroSettle.restoreEntitlements() } returns Result.failure(
            ZeroSettleError.UserNotIdentified,
        )
        val result = newResult()

        handler.handle(call("restoreEntitlements"), result)

        verify { result.error(eq("user_not_identified"), any(), null) }
    }

    @Test
    fun `restoreEntitlements maps SDK throw to sdk_error`() = runTest {
        coEvery { ZeroSettle.restoreEntitlements() } throws RuntimeException("boom")
        val result = newResult()

        handler.handle(call("restoreEntitlements"), result)

        verify { result.error("sdk_error", "boom", null) }
    }
}
