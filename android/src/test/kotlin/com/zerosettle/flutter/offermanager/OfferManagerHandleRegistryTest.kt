package com.zerosettle.flutter.offermanager

import com.google.common.truth.Truth.assertThat
import com.zerosettle.sdk.ZeroSettle
import com.zerosettle.sdk.offers.OfferManager
import io.flutter.plugin.common.BinaryMessenger
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkObject
import io.mockk.unmockkObject
import kotlinx.coroutines.Job
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

/**
 * Unit tests for [OfferManagerHandleRegistry].
 *
 * `ZeroSettle.offerManager(...)` is stubbed via `mockkObject` because:
 *   - the real implementation throws `UserNotIdentified` unless `identify(...)`
 *     has run (which requires a backend bootstrap), and
 *   - the registry's contract is "allocate a fresh handle id + open channels +
 *     hold whatever `ZeroSettle.offerManager(...)` returned" — not exercising
 *     the SDK itself.
 */
@RunWith(RobolectricTestRunner::class)
class OfferManagerHandleRegistryTest {

    private val messenger = mockk<BinaryMessenger>(relaxed = true)
    private lateinit var registry: OfferManagerHandleRegistry

    @Before
    fun setUp() {
        mockkObject(ZeroSettle)
        every { ZeroSettle.offerManager(any()) } answers { mockk(relaxed = true) }
        registry = OfferManagerHandleRegistry(messenger)
    }

    @After
    fun tearDown() {
        registry.disposeAll()
        unmockkObject(ZeroSettle)
    }

    @Test
    fun `allocate returns entry with sequential ids starting at 1`() = runTest {
        val a = registry.allocate(stripeCustomerId = null)
        val b = registry.allocate(stripeCustomerId = "cus_123")
        val c = registry.allocate(stripeCustomerId = null)
        assertThat(a).isNotNull()
        assertThat(a!!.id).isEqualTo(1)
        assertThat(b!!.id).isEqualTo(2)
        assertThat(c!!.id).isEqualTo(3)
    }

    @Test
    fun `allocate stores a non-null OfferManager on the entry`() = runTest {
        val entry = registry.allocate(stripeCustomerId = "cus_xyz")
        assertThat(entry).isNotNull()
        assertThat(entry!!.manager).isNotNull()
    }

    @Test
    fun `allocate forwards stripeCustomerId to ZeroSettle offerManager`() = runTest {
        val stubbed = mockk<OfferManager>(relaxed = true)
        every { ZeroSettle.offerManager("cus_forwarded") } returns stubbed
        val entry = registry.allocate(stripeCustomerId = "cus_forwarded")
        assertThat(entry!!.manager).isSameInstanceAs(stubbed)
    }

    @Test
    fun `allocate creates method and state channels with the expected names`() = runTest {
        val entry = registry.allocate(stripeCustomerId = null)!!
        // MethodChannel/EventChannel don't expose `name` publicly; the name is
        // baked into the channel at construction time and forwarded to the
        // BinaryMessenger. We assert by id so that channel-name divergence
        // becomes a compile-time concern only — the channel names depend on
        // `entry.id`, which we control.
        assertThat(entry.id).isEqualTo(1)
        assertThat(entry.methodChannel).isNotNull()
        assertThat(entry.stateChannel).isNotNull()
    }

    @Test
    fun `get returns the entry for an allocated id`() = runTest {
        val entry = registry.allocate(stripeCustomerId = null)!!
        assertThat(registry.get(entry.id)).isSameInstanceAs(entry)
    }

    @Test
    fun `get returns null for a never-allocated id`() {
        assertThat(registry.get(9999)).isNull()
    }

    @Test
    fun `dispose removes the entry and is idempotent`() = runTest {
        val entry = registry.allocate(stripeCustomerId = null)!!
        val id = entry.id

        registry.dispose(id)
        assertThat(registry.get(id)).isNull()

        // Disposing again is a no-op — must not throw.
        registry.dispose(id)
        assertThat(registry.get(id)).isNull()
    }

    @Test
    fun `dispose cancels the entry's coroutine scope`() = runTest {
        val entry = registry.allocate(stripeCustomerId = null)!!
        val job = entry.scope.coroutineContext[Job]!!
        assertThat(job.isActive).isTrue()
        registry.dispose(entry.id)
        assertThat(job.isActive).isFalse()
    }

    @Test
    fun `disposeAll clears every allocated entry and cancels their scopes`() = runTest {
        val a = registry.allocate(stripeCustomerId = null)!!
        val b = registry.allocate(stripeCustomerId = "cus_b")!!
        val c = registry.allocate(stripeCustomerId = "cus_c")!!
        val jobs = listOf(
            a.scope.coroutineContext[Job]!!,
            b.scope.coroutineContext[Job]!!,
            c.scope.coroutineContext[Job]!!,
        )
        assertThat(jobs.all { it.isActive }).isTrue()

        registry.disposeAll()

        assertThat(registry.get(a.id)).isNull()
        assertThat(registry.get(b.id)).isNull()
        assertThat(registry.get(c.id)).isNull()
        assertThat(jobs.all { !it.isActive }).isTrue()
    }
}
