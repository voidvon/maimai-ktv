#include <android/log.h>
#include <dlfcn.h>
#include <jni.h>
#include <stdint.h>

typedef struct libvlc_media_player_t libvlc_media_player_t;
typedef struct vlc_object_t vlc_object_t;

/* Internal ABI from the pinned libvlc-all 3.6.0 / VLC 3.0.21 build. */
typedef union {
    int64_t i_int;
    float f_float;
    char *psz_string;
    void *p_address;
} vlc_value_t;

typedef struct {
    int i_type;
    int i_count;
    vlc_value_t *p_values;
} vlc_list_t;

typedef int (*libvlc_audio_set_channel_fn)(libvlc_media_player_t *, int);
typedef int (*var_create_fn)(vlc_object_t *, const char *, int);
typedef int (*var_set_checked_fn)(vlc_object_t *, const char *, int, vlc_value_t);
typedef int (*var_type_fn)(vlc_object_t *, const char *);
typedef vlc_list_t *(*vlc_list_children_fn)(vlc_object_t *);
typedef void (*vlc_list_release_fn)(vlc_list_t *);

enum {
    VLC_VAR_CLASS = 0x00f0,
    VLC_VAR_INTEGER = 0x0030,
    VLC_VAR_STRING = 0x0040,
    VLC_VAR_FLOAT = 0x0050,
    MAX_OBJECT_SEARCH_DEPTH = 12,
    PITCH_APPLIED_TO_PLAYER = 1 << 0,
    PITCH_APPLIED_TO_AUDIO_OUTPUT = 1 << 1,
};

static void *g_libvlc_handle = NULL;
static libvlc_audio_set_channel_fn g_libvlc_audio_set_channel = NULL;
static var_create_fn g_var_create = NULL;
static var_set_checked_fn g_var_set_checked = NULL;
static var_type_fn g_var_type = NULL;
static vlc_list_children_fn g_vlc_list_children = NULL;
static vlc_list_release_fn g_vlc_list_release = NULL;
static int g_audio_channel_symbol_state = 0;
static int g_pitch_symbols_state = 0;

static int ensure_libvlc_handle(void) {
    if (g_libvlc_handle != NULL) {
        return 1;
    }

    g_libvlc_handle = dlopen("libvlc.so", RTLD_NOW | RTLD_GLOBAL);
    if (g_libvlc_handle == NULL) {
        __android_log_print(
            ANDROID_LOG_WARN,
            "KtvVlcBridge",
            "dlopen libvlc.so failed: %s",
            dlerror());
        return 0;
    }
    return 1;
}

static libvlc_audio_set_channel_fn resolve_libvlc_audio_set_channel(void) {
    if (g_audio_channel_symbol_state != 0) {
        return g_libvlc_audio_set_channel;
    }
    if (!ensure_libvlc_handle()) {
        g_audio_channel_symbol_state = -1;
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
        g_audio_channel_symbol_state = -1;
        return NULL;
    }

    g_audio_channel_symbol_state = 1;
    return g_libvlc_audio_set_channel;
}

static int resolve_pitch_symbols(void) {
    if (g_pitch_symbols_state != 0) {
        return g_pitch_symbols_state > 0;
    }
    if (!ensure_libvlc_handle()) {
        g_pitch_symbols_state = -1;
        return 0;
    }

    g_var_create = (var_create_fn)dlsym(g_libvlc_handle, "var_Create");
    g_var_set_checked =
        (var_set_checked_fn)dlsym(g_libvlc_handle, "var_SetChecked");
    g_var_type = (var_type_fn)dlsym(g_libvlc_handle, "var_Type");
    g_vlc_list_children =
        (vlc_list_children_fn)dlsym(g_libvlc_handle, "vlc_list_children");
    g_vlc_list_release =
        (vlc_list_release_fn)dlsym(g_libvlc_handle, "vlc_list_release");

    if (g_var_create == NULL ||
        g_var_set_checked == NULL ||
        g_var_type == NULL ||
        g_vlc_list_children == NULL ||
        g_vlc_list_release == NULL) {
        __android_log_print(
            ANDROID_LOG_WARN,
            "KtvVlcBridge",
            "Unable to resolve VLC pitch-control symbols: %s",
            dlerror());
        g_pitch_symbols_state = -1;
        return 0;
    }

    g_pitch_symbols_state = 1;
    return 1;
}

static int set_pitch_variables(vlc_object_t *object, float semitones) {
    int pitch_type = g_var_type(object, "pitch-shift") & VLC_VAR_CLASS;
    if (pitch_type == 0) {
        if (g_var_create(object, "pitch-shift", VLC_VAR_FLOAT) != 0) {
            return 0;
        }
        pitch_type = g_var_type(object, "pitch-shift") & VLC_VAR_CLASS;
    }
    if (pitch_type != VLC_VAR_FLOAT) {
        return 0;
    }

    vlc_value_t pitch_value = {0};
    pitch_value.f_float = semitones;
    const int pitch_result =
        g_var_set_checked(object, "pitch-shift", VLC_VAR_FLOAT, pitch_value);

    vlc_value_t filter_value = {0};
    filter_value.psz_string = "scaletempo_pitch";
    const int filter_result =
        g_var_set_checked(object, "audio-filter", VLC_VAR_STRING, filter_value);
    return pitch_result == 0 && filter_result == 0;
}

/*
 * The media player and audio output both own an audio-filter variable. Only
 * the audio output also owns stereo-mode and can restart the active pipeline.
 */
static int set_pitch_shift_on_player_tree(
    vlc_object_t *object,
    float semitones,
    int depth) {
    const int audio_filter_type = g_var_type(object, "audio-filter") & VLC_VAR_CLASS;
    const int stereo_mode_type = g_var_type(object, "stereo-mode") & VLC_VAR_CLASS;
    int result = 0;

    if (depth == 0 && audio_filter_type == VLC_VAR_STRING) {
        const int applied = set_pitch_variables(object, semitones);
        if (applied) {
            result |= PITCH_APPLIED_TO_PLAYER;
        }
        __android_log_print(
            applied ? ANDROID_LOG_INFO : ANDROID_LOG_WARN,
            "KtvVlcBridge",
            "set media-player pitch semitones=%.2f applied=%d",
            semitones,
            applied);
    }

    if (
        depth > 0 &&
        audio_filter_type == VLC_VAR_STRING &&
        stereo_mode_type == VLC_VAR_INTEGER) {
        const int applied = set_pitch_variables(object, semitones);

        __android_log_print(
            applied ? ANDROID_LOG_INFO : ANDROID_LOG_WARN,
            "KtvVlcBridge",
            "set audio-output pitch semitones=%.2f applied=%d",
            semitones,
            applied);
        return applied ? PITCH_APPLIED_TO_AUDIO_OUTPUT : 0;
    }

    if (depth >= MAX_OBJECT_SEARCH_DEPTH) {
        return result;
    }

    vlc_list_t *children = g_vlc_list_children(object);
    if (children == NULL) {
        return result;
    }

    for (int index = 0; index < children->i_count; index++) {
        result |= set_pitch_shift_on_player_tree(
            (vlc_object_t *)children->p_values[index].p_address,
            semitones,
            depth + 1);
    }
    g_vlc_list_release(children);
    return result;
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

JNIEXPORT jint JNICALL
Java_com_ktv_player_ktv2_NativeKtvPlayerHost_nativeSetPitchShift(
    JNIEnv *env,
    jobject thiz,
    jlong player_instance,
    jfloat semitones) {
    (void)env;
    (void)thiz;

    if (player_instance == 0 || !resolve_pitch_symbols()) {
        return 0;
    }

    const int applied = set_pitch_shift_on_player_tree(
        (vlc_object_t *)(uintptr_t)player_instance,
        (float)semitones,
        0);
    if ((applied & PITCH_APPLIED_TO_PLAYER) == 0) {
        __android_log_print(
            ANDROID_LOG_WARN,
            "KtvVlcBridge",
            "VLC media player rejected pitch configuration");
    } else if ((applied & PITCH_APPLIED_TO_AUDIO_OUTPUT) == 0) {
        __android_log_print(
            ANDROID_LOG_INFO,
            "KtvVlcBridge",
            "Pitch configured on media player; waiting for audio output");
    }
    return (jint)applied;
}
