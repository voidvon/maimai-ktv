#include <android/log.h>
#include <dlfcn.h>
#include <jni.h>
#include <stdint.h>

typedef struct libvlc_media_player_t libvlc_media_player_t;
typedef int (*libvlc_audio_set_channel_fn)(libvlc_media_player_t *, int);

static void *g_libvlc_handle = NULL;
static libvlc_audio_set_channel_fn g_libvlc_audio_set_channel = NULL;
static int g_symbol_resolution_state = 0;

static libvlc_audio_set_channel_fn resolve_libvlc_audio_set_channel(void) {
    if (g_symbol_resolution_state != 0) {
        return g_libvlc_audio_set_channel;
    }

    g_libvlc_handle = dlopen("libvlc.so", RTLD_NOW | RTLD_GLOBAL);
    if (g_libvlc_handle == NULL) {
        __android_log_print(
            ANDROID_LOG_WARN,
            "KtvVlcBridge",
            "dlopen libvlc.so failed: %s",
            dlerror());
        g_symbol_resolution_state = -1;
        return NULL;
    }

    g_libvlc_audio_set_channel =
        (libvlc_audio_set_channel_fn)dlsym(g_libvlc_handle, "libvlc_audio_set_channel");
    if (g_libvlc_audio_set_channel == NULL) {
        __android_log_print(
            ANDROID_LOG_WARN,
            "KtvVlcBridge",
            "dlsym libvlc_audio_set_channel failed: %s",
            dlerror());
        g_symbol_resolution_state = -1;
        return NULL;
    }

    g_symbol_resolution_state = 1;
    return g_libvlc_audio_set_channel;
}

JNIEXPORT jboolean JNICALL
Java_com_ktv_player_ktv2_NativeKtvPlayerHost_nativeSetAudioChannel(
    JNIEnv *env,
    jobject thiz,
    jlong player_instance,
    jint channel) {
    (void)env;
    (void)thiz;

    if (player_instance == 0) {
        return JNI_FALSE;
    }

    libvlc_audio_set_channel_fn set_audio_channel = resolve_libvlc_audio_set_channel();
    if (set_audio_channel == NULL) {
        return JNI_FALSE;
    }

    const int result =
        set_audio_channel((libvlc_media_player_t *)(uintptr_t)player_instance, (int)channel);
    return result == 0 ? JNI_TRUE : JNI_FALSE;
}
