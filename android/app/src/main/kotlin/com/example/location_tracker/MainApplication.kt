package com.example.location_tracker // <--- MUST MATCH FOLDER STRUCTURE

import android.app.Application
import com.yandex.mapkit.MapKitFactory

class MainApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        // Ensure your API key is correct here
        MapKitFactory.setApiKey("4d918188-7ec1-45d4-9742-fa4b872c7d76")
    }
}