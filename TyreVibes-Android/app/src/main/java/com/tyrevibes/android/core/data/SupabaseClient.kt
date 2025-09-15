package com.tyrevibes.android.core.data

import io.supabase.gotrue.GoTrue
import io.supabase.gotrue.gotrue

import com.tyrevibes.android.BuildConfig

object SupabaseClient {
    val client: GoTrue = gotrue(
        url = BuildConfig.SUPABASE_URL,
        headers = mapOf(
            "apikey" to BuildConfig.SUPABASE_KEY
        )
    )
}
