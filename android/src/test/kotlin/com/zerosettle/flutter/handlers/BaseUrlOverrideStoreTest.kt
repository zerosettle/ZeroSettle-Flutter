package com.zerosettle.flutter.handlers

import com.google.common.truth.Truth.assertThat
import org.junit.After
import org.junit.Test

class BaseUrlOverrideStoreTest {

    @After
    fun tearDown() {
        BaseUrlOverrideStore.consume()
    }

    @Test
    fun `set then consume returns the staged value`() {
        BaseUrlOverrideStore.set("https://api-staging.zerosettle.io/v1")
        assertThat(BaseUrlOverrideStore.consume()).isEqualTo("https://api-staging.zerosettle.io/v1")
    }

    @Test
    fun `consume clears the slot`() {
        BaseUrlOverrideStore.set("https://example.com")
        BaseUrlOverrideStore.consume()
        assertThat(BaseUrlOverrideStore.consume()).isNull()
    }

    @Test
    fun `consume returns null when nothing staged`() {
        assertThat(BaseUrlOverrideStore.consume()).isNull()
    }

    @Test
    fun `set with null clears`() {
        BaseUrlOverrideStore.set("https://example.com")
        BaseUrlOverrideStore.set(null)
        assertThat(BaseUrlOverrideStore.consume()).isNull()
    }

    @Test
    fun `set with blank string clears`() {
        BaseUrlOverrideStore.set("https://example.com")
        BaseUrlOverrideStore.set("   ")
        assertThat(BaseUrlOverrideStore.consume()).isNull()
    }

    @Test
    fun `subsequent set overwrites prior value`() {
        BaseUrlOverrideStore.set("https://first.example.com")
        BaseUrlOverrideStore.set("https://second.example.com")
        assertThat(BaseUrlOverrideStore.consume()).isEqualTo("https://second.example.com")
    }
}
