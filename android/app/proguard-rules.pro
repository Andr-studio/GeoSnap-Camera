# ── Flutter engine ────────────────────────────────────────────────────────────
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.**

# ── FFmpeg Kit (ffmpeg_kit_flutter_new) ───────────────────────────────────────
# Without these rules R8 strips the JNI bridge and native calls silently fail,
# causing a black screen on first launch in release mode.
-keep class com.arthenica.** { *; }
-dontwarn com.arthenica.**

# ── CameraAwesome ─────────────────────────────────────────────────────────────
-keep class com.apparence.camerawesome.** { *; }
-dontwarn com.apparence.camerawesome.**

# ── image_editor ──────────────────────────────────────────────────────────────
-keep class com.fluttercandies.** { *; }
-dontwarn com.fluttercandies.**

# ── native_exif ───────────────────────────────────────────────────────────────
-keep class com.nativeexif.** { *; }
-keep class androidx.exifinterface.** { *; }
-dontwarn com.nativeexif.**

# ── Geolocator / Geocoding ────────────────────────────────────────────────────
-keep class com.baseflow.geolocator.** { *; }
-keep class com.baseflow.geocoding.** { *; }
-dontwarn com.baseflow.**

# ── sensors_plus ──────────────────────────────────────────────────────────────
-keep class dev.fluttercommunity.plus.sensors.** { *; }
-dontwarn dev.fluttercommunity.plus.**

# ── share_plus ────────────────────────────────────────────────────────────────
-keep class dev.fluttercommunity.plus.share.** { *; }

# ── path_provider ─────────────────────────────────────────────────────────────
-keep class io.flutter.plugins.pathprovider.** { *; }

# ── video_player ──────────────────────────────────────────────────────────────
-keep class io.flutter.plugins.videoplayer.** { *; }
-dontwarn io.flutter.plugins.videoplayer.**

# ── Kotlin & Coroutines ───────────────────────────────────────────────────────
-keep class kotlin.** { *; }
-keep class kotlinx.coroutines.** { *; }
-dontwarn kotlin.**
-dontwarn kotlinx.**

# ── Android Intent Plus ───────────────────────────────────────────────────────
-keep class dev.fluttercommunity.plus.androidintent.** { *; }

# ── Shared Preferences ────────────────────────────────────────────────────────
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# ── General: keep all native JNI methods ─────────────────────────────────────
-keepclasseswithmembernames class * {
    native <methods>;
}

# ── Prevent stripping enums (common source of runtime crashes) ────────────────
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# ── Prevent stripping Parcelable implementations ──────────────────────────────
-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}
