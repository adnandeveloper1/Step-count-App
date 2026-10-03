package com.nexappra.buildup

import android.app.Application

class MainApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        // Modern Workmanager with V2 embedding handles plugin registration automatically
        // for packages listed in pubspec.yaml.
    }
}
