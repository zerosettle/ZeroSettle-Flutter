package com.zerosettle.flutter.handlers

import android.app.Activity
import android.content.Context
import com.google.common.truth.Truth.assertThat
import com.zerosettle.sdk.Identity
import com.zerosettle.sdk.ZeroSettle
import com.zerosettle.sdk.ZeroSettleConfig
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
 * Unit tests for [IdentityHandler].
 *
 * Strategy:
 *   - Stub the `ZeroSettle` singleton via `mockkObject(ZeroSettle)` — same
 *     pattern as [com.zerosettle.flutter.offermanager.OfferManagerStaticHandlerTest].
 *   - `UnconfinedTestDispatcher` runs `scope.launch { ... }` synchronously
 *     so `verify { result.success(...) }` fires after the suspending SDK
 *     call resolves.
 *   - Application context is provided through the [HandlerDependencies]
 *     bundle — Robolectric isn't strictly required, but it's the same
 *     runtime the other handler tests use.
 *
 * Coverage matches the wire shapes documented on the iOS plugin
 * (`ZeroSettlePlugin.swift:304-425, 863-888`): success returns, missing
 * required args, SDK Result.failure mapping, SDK throw mapping.
 */
@OptIn(ExperimentalCoroutinesApi::class)
@RunWith(RobolectricTestRunner::class)
class IdentityHandlerTest {

    private val scope = CoroutineScope(SupervisorJob() + UnconfinedTestDispatcher())
    private val appContext: Context = mockk(relaxed = true)
    private val activity: Activity = mockk(relaxed = true)
    private lateinit var handler: IdentityHandler

    @Before
    fun setUp() {
        mockkObject(ZeroSettle)
        // Default StateFlow stubs — individual tests override.
        every { ZeroSettle.currentUserId } returns MutableStateFlow(null)
        every { ZeroSettle.isBootstrapped } returns MutableStateFlow(false)
        every { ZeroSettle.isConfigured } returns MutableStateFlow(false)

        val deps = HandlerDependencies(
            scope = scope,
            activityProvider = { activity },
            applicationContextProvider = { appContext },
        )
        handler = IdentityHandler(deps)
    }

    @After
    fun tearDown() {
        unmockkObject(ZeroSettle)
        scope.cancel()
    }

    private fun call(method: String, args: Map<String, Any?>? = null) = MethodCall(method, args)
    private fun newResult() = mockk<MethodChannel.Result>(relaxed = true)

    // ─── handle() routing ───────────────────────────────────────────────

    @Test
    fun `handle returns false for unknown method`() {
        val result = newResult()
        val consumed = handler.handle(call("definitelyNotMine"), result)
        assertThat(consumed).isFalse()
        // The handler must NOT have called success or error — it's the
        // plugin's job to fall through.
        verify(exactly = 0) { result.success(any()) }
        verify(exactly = 0) { result.error(any(), any(), any()) }
    }

    @Test
    fun `handle returns true for owned method`() {
        val consumed = handler.handle(call("getIsConfigured"), newResult())
        assertThat(consumed).isTrue()
    }

    // ─── configure ──────────────────────────────────────────────────────

    @Test
    fun `configure forwards publishableKey and returns success(null)`() {
        every { ZeroSettle.configure(appContext, any()) } answers { }
        val result = newResult()
        val configSlot = slot<ZeroSettleConfig>()
        every { ZeroSettle.configure(eq(appContext), capture(configSlot)) } answers { }

        handler.handle(call("configure", mapOf("publishableKey" to "zs_pk_test_abc")), result)

        verify { ZeroSettle.configure(appContext, any()) }
        verify { result.success(null) }
        assertThat(configSlot.captured.publishableKey).isEqualTo("zs_pk_test_abc")
        assertThat(configSlot.captured.preloadCheckout).isFalse()
    }

    @Test
    fun `configure forwards preloadCheckout when true`() {
        val configSlot = slot<ZeroSettleConfig>()
        every { ZeroSettle.configure(eq(appContext), capture(configSlot)) } answers { }

        handler.handle(
            call(
                "configure",
                mapOf("publishableKey" to "zs_pk_test_abc", "preloadCheckout" to true),
            ),
            newResult(),
        )

        assertThat(configSlot.captured.preloadCheckout).isTrue()
    }

    @Test
    fun `configure drops iOS-only args silently`() {
        val configSlot = slot<ZeroSettleConfig>()
        every { ZeroSettle.configure(eq(appContext), capture(configSlot)) } answers { }

        handler.handle(
            call(
                "configure",
                mapOf(
                    "publishableKey" to "zs_pk_test_abc",
                    "syncStoreKitTransactions" to true,
                    "appleMerchantId" to "merchant.foo",
                    "maxPreloadedWebViews" to 3,
                    "applePaySetupBehavior" to "presentBuiltInUI",
                ),
            ),
            newResult(),
        )

        // None of the iOS-only knobs land on ZeroSettleConfig — only
        // publishableKey + preloadCheckout default.
        assertThat(configSlot.captured.publishableKey).isEqualTo("zs_pk_test_abc")
        assertThat(configSlot.captured.preloadCheckout).isFalse()
    }

    @Test
    fun `configure errors on missing publishableKey`() {
        val result = newResult()

        handler.handle(call("configure", emptyMap<String, Any?>()), result)

        verify { result.error("INVALID_ARGUMENTS", "publishableKey is required", null) }
        verify(exactly = 0) { ZeroSettle.configure(any(), any()) }
    }

    @Test
    fun `configure errors when plugin not attached (no application context)`() {
        // Rebuild the handler with a null-returning context provider.
        val depsNoCtx = HandlerDependencies(
            scope = scope,
            activityProvider = { activity },
            applicationContextProvider = { null },
        )
        val handlerNoCtx = IdentityHandler(depsNoCtx)
        val result = newResult()

        handlerNoCtx.handle(
            call("configure", mapOf("publishableKey" to "zs_pk_test_abc")),
            result,
        )

        verify { result.error("plugin_not_attached", any(), null) }
        verify(exactly = 0) { ZeroSettle.configure(any(), any()) }
    }

    // ─── identify ───────────────────────────────────────────────────────

    @Test
    fun `identify with user type forwards id+name+email and returns catalog map`() = runTest {
        val catalog = ProductCatalog(products = emptyList())
        coEvery { ZeroSettle.identify(any()) } returns Result.success(catalog)
        val result = newResult()

        handler.handle(
            call(
                "identify",
                mapOf(
                    "type" to "user",
                    "id" to "u1",
                    "name" to "Alice",
                    "email" to "a@example.com",
                ),
            ),
            result,
        )

        coVerify {
            ZeroSettle.identify(Identity.User(id = "u1", name = "Alice", email = "a@example.com"))
        }
        verify { result.success(mapOf("products" to emptyList<Any?>())) }
    }

    @Test
    fun `identify with anonymous type returns catalog map`() = runTest {
        val catalog = ProductCatalog(products = emptyList())
        coEvery { ZeroSettle.identify(Identity.Anonymous) } returns Result.success(catalog)
        val result = newResult()

        handler.handle(call("identify", mapOf("type" to "anonymous")), result)

        coVerify { ZeroSettle.identify(Identity.Anonymous) }
        verify { result.success(mapOf("products" to emptyList<Any?>())) }
    }

    @Test
    fun `identify with deferred type returns null map (no catalog)`() = runTest {
        coEvery { ZeroSettle.identify(Identity.Deferred) } returns Result.success(null)
        val result = newResult()

        handler.handle(call("identify", mapOf("type" to "deferred")), result)

        verify { result.success(null) }
    }

    @Test
    fun `identify encodes catalog product into wire shape`() = runTest {
        val product = Product(
            id = "com.foo.bar",
            displayName = "Bar",
            productDescription = "A product",
            type = ProductType.NON_CONSUMABLE,
            syncedToAppStoreConnect = true,
        )
        coEvery { ZeroSettle.identify(any()) } returns Result.success(
            ProductCatalog(products = listOf(product)),
        )
        val mapSlot = slot<Map<String, Any?>>()
        val result = newResult()
        every { result.success(capture(mapSlot)) } answers { }

        handler.handle(
            call("identify", mapOf("type" to "user", "id" to "u1")),
            result,
        )

        // Encoded products list has the expected first row id.
        @Suppress("UNCHECKED_CAST")
        val products = mapSlot.captured["products"] as List<Map<String, Any?>>
        assertThat(products).hasSize(1)
        assertThat(products[0]["id"]).isEqualTo("com.foo.bar")
    }

    @Test
    fun `identify errors on missing type`() {
        val result = newResult()
        handler.handle(call("identify", emptyMap<String, Any?>()), result)
        verify { result.error("INVALID_ARGUMENTS", "type is required", null) }
    }

    @Test
    fun `identify errors on user without id`() {
        val result = newResult()
        handler.handle(call("identify", mapOf("type" to "user")), result)
        verify {
            result.error("INVALID_ARGUMENTS", "id is required for user identity", null)
        }
    }

    @Test
    fun `identify errors on unknown identity type`() {
        val result = newResult()
        handler.handle(call("identify", mapOf("type" to "ghost")), result)
        verify {
            result.error("INVALID_ARGUMENTS", "unknown identity type: ghost", null)
        }
    }

    @Test
    fun `identify maps SDK Result_failure to typed error code`() = runTest {
        coEvery { ZeroSettle.identify(any()) } returns Result.failure(ZeroSettleError.NotConfigured)
        val result = newResult()

        handler.handle(call("identify", mapOf("type" to "user", "id" to "u1")), result)

        verify { result.error(eq("not_configured"), any(), null) }
    }

    @Test
    fun `identify maps SDK throw to sdk_error`() = runTest {
        coEvery { ZeroSettle.identify(any()) } throws RuntimeException("boom")
        val result = newResult()

        handler.handle(call("identify", mapOf("type" to "user", "id" to "u1")), result)

        verify { result.error("sdk_error", "boom", null) }
    }

    // ─── bootstrap (legacy 1.2.x shim) ──────────────────────────────────

    @Test
    fun `bootstrap shims into identify(user) and returns catalog`() = runTest {
        coEvery {
            ZeroSettle.identify(Identity.User(id = "u9", name = null, email = null))
        } returns Result.success(ProductCatalog(products = emptyList()))
        val result = newResult()

        handler.handle(call("bootstrap", mapOf("userId" to "u9")), result)

        coVerify { ZeroSettle.identify(Identity.User(id = "u9", name = null, email = null)) }
        verify { result.success(mapOf("products" to emptyList<Any?>())) }
    }

    @Test
    fun `bootstrap errors on missing userId`() {
        val result = newResult()
        handler.handle(call("bootstrap", emptyMap<String, Any?>()), result)
        verify {
            result.error(
                "INVALID_ARGUMENTS",
                "userId is required for legacy bootstrap()",
                null,
            )
        }
    }

    // ─── logout ─────────────────────────────────────────────────────────

    @Test
    fun `logout calls SDK and returns success(null)`() = runTest {
        every { ZeroSettle.logout() } answers { }
        val result = newResult()

        handler.handle(call("logout"), result)

        verify { ZeroSettle.logout() }
        verify { result.success(null) }
    }

    @Test
    fun `logout maps SDK throw to sdk_error`() = runTest {
        every { ZeroSettle.logout() } throws RuntimeException("nope")
        val result = newResult()

        handler.handle(call("logout"), result)

        verify { result.error("sdk_error", "nope", null) }
    }

    // ─── setCustomer ────────────────────────────────────────────────────

    @Test
    fun `setCustomer forwards both args and returns success(null)`() = runTest {
        every { ZeroSettle.setCustomer(any(), any()) } answers { }
        val result = newResult()

        handler.handle(
            call("setCustomer", mapOf("name" to "Alice", "email" to "a@example.com")),
            result,
        )

        verify { ZeroSettle.setCustomer("Alice", "a@example.com") }
        verify { result.success(null) }
    }

    @Test
    fun `setCustomer forwards null args (clear-by-omission)`() = runTest {
        every { ZeroSettle.setCustomer(null, null) } answers { }
        val result = newResult()

        handler.handle(call("setCustomer", emptyMap<String, Any?>()), result)

        verify { ZeroSettle.setCustomer(null, null) }
        verify { result.success(null) }
    }

    // ─── transferStoreKitOwnershipToCurrentUser (iOS-only on the wire) ──

    @Test
    fun `transferStoreKitOwnershipToCurrentUser returns not_implemented`() {
        val result = newResult()

        handler.handle(
            call(
                "transferStoreKitOwnershipToCurrentUser",
                mapOf("productId" to "com.foo.bar"),
            ),
            result,
        )

        verify { result.error(eq("not_implemented"), any(), null) }
    }

    // ─── State queries ─────────────────────────────────────────────────

    @Test
    fun `getCurrentUserId returns null when no identify ran`() {
        every { ZeroSettle.currentUserId } returns MutableStateFlow(null)
        val result = newResult()

        handler.handle(call("getCurrentUserId"), result)

        verify { result.success(null) }
    }

    @Test
    fun `getCurrentUserId returns id from currentUserId StateFlow`() {
        every { ZeroSettle.currentUserId } returns MutableStateFlow("u7")
        val result = newResult()

        handler.handle(call("getCurrentUserId"), result)

        verify { result.success("u7") }
    }

    @Test
    fun `getIsBootstrapped returns false initially`() {
        every { ZeroSettle.isBootstrapped } returns MutableStateFlow(false)
        val result = newResult()

        handler.handle(call("getIsBootstrapped"), result)

        verify { result.success(false) }
    }

    @Test
    fun `getIsBootstrapped returns true after bootstrap`() {
        every { ZeroSettle.isBootstrapped } returns MutableStateFlow(true)
        val result = newResult()

        handler.handle(call("getIsBootstrapped"), result)

        verify { result.success(true) }
    }

    @Test
    fun `getIsConfigured returns true after configure`() {
        every { ZeroSettle.isConfigured } returns MutableStateFlow(true)
        val result = newResult()

        handler.handle(call("getIsConfigured"), result)

        verify { result.success(true) }
    }
}
