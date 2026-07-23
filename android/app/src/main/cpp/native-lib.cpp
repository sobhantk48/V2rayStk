#include <jni.h>
#include <atomic>

static std::atomic<long long> uploaded{0};
static std::atomic<long long> downloaded{0};

extern "C" JNIEXPORT jboolean JNICALL
Java_com_v2raystk_app_LibboxBridge_start(JNIEnv*, jobject, jstring, jint tunFd) {
    // Integration seam: link the official libbox AAR/shared library and pass
    // config plus tunFd to its platform start function here.
    return tunFd >= 0 ? JNI_TRUE : JNI_FALSE;
}
extern "C" JNIEXPORT void JNICALL Java_com_v2raystk_app_LibboxBridge_stop(JNIEnv*, jobject) {}
extern "C" JNIEXPORT jlongArray JNICALL Java_com_v2raystk_app_LibboxBridge_traffic(JNIEnv* env, jobject) {
    jlong values[2] = {uploaded.load(), downloaded.load()};
    jlongArray result = env->NewLongArray(2); env->SetLongArrayRegion(result, 0, 2, values); return result;
}
