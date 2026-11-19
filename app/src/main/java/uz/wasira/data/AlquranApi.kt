package uz.wasira.data

import okhttp3.HttpUrl
import okhttp3.OkHttpClient
import uz.wasira.domain.Edition

class AlquranApi(
    private val client: OkHttpClient,
    private val baseUrl: HttpUrl,
) : QuranApi {
    override suspend fun translations(): List<Edition> = TODO("Agent A")
    override suspend fun ayah(number: Int, translation: String?): FetchedAyah = TODO("Agent A")

    companion object {
        const val BASE_URL = "https://api.alquran.cloud/v1/"
    }
}
