#include "ofxGgmlAudioWhisperBackend.h"

#include "ofxGgmlAudioUtils.h"

#if defined(OFXGGMLAUDIO_WITH_WHISPER) && __has_include(<whisper.h>)
	#include <whisper.h>
	#define OFXGGMLAUDIO_HAS_WHISPER 1
#else
	#define OFXGGMLAUDIO_HAS_WHISPER 0
#endif

namespace {
	ofxGgmlAudioResult makeError(const std::string& message) {
		ofxGgmlAudioResult result;
		result.success = false;
		result.error = message;
		return result;
	}

	ofxGgmlAudioResult makeOk(const std::string& message) {
		ofxGgmlAudioResult result;
		result.success = true;
		result.text = message;
		return result;
	}
}

struct ofxGgmlAudioWhisperBackend::Impl {
	ofxGgmlAudioWhisperSettings settings;
#if OFXGGMLAUDIO_HAS_WHISPER
	whisper_context* context = nullptr;
#endif

	~Impl() {
		close();
	}

	bool isAvailable() const {
		return OFXGGMLAUDIO_HAS_WHISPER != 0;
	}

	bool isLoaded() const {
#if OFXGGMLAUDIO_HAS_WHISPER
		return context != nullptr;
#else
		return false;
#endif
	}

	void close() {
#if OFXGGMLAUDIO_HAS_WHISPER
		if (context) {
			whisper_free(context);
			context = nullptr;
		}
#endif
	}
};

ofxGgmlAudioWhisperBackend::ofxGgmlAudioWhisperBackend()
	: impl(std::make_unique<Impl>()) {
}

ofxGgmlAudioWhisperBackend::~ofxGgmlAudioWhisperBackend() = default;
ofxGgmlAudioWhisperBackend::ofxGgmlAudioWhisperBackend(ofxGgmlAudioWhisperBackend&& other) noexcept = default;
ofxGgmlAudioWhisperBackend& ofxGgmlAudioWhisperBackend::operator=(ofxGgmlAudioWhisperBackend&& other) noexcept = default;

bool ofxGgmlAudioWhisperBackend::isAvailable() const {
	return impl && impl->isAvailable();
}

bool ofxGgmlAudioWhisperBackend::isLoaded() const {
	return impl && impl->isLoaded();
}

std::string ofxGgmlAudioWhisperBackend::getBackendName() const {
	return "whisper.cpp";
}

ofxGgmlAudioWhisperSettings ofxGgmlAudioWhisperBackend::getSettings() const {
	return impl ? impl->settings : ofxGgmlAudioWhisperSettings{};
}

ofxGgmlAudioResult ofxGgmlAudioWhisperBackend::setup(const ofxGgmlAudioWhisperSettings& settings) {
	if (!impl) {
		return makeError("whisper backend is not initialized");
	}
	impl->close();
	impl->settings = settings;

#if OFXGGMLAUDIO_HAS_WHISPER
	if (!settings.hasModelPath()) {
		return makeError("no Whisper model path was configured");
	}

	whisper_context_params params = whisper_context_default_params();
	impl->context = whisper_init_from_file_with_params(settings.modelPath.c_str(), params);
	if (!impl->context) {
		return makeError("whisper.cpp failed to create a context");
	}
	return makeOk("whisper.cpp context loaded");
#else
	(void)settings;
	return makeError("whisper.cpp backend is not enabled. Run scripts/build-whisper.*, then compile with OFXGGMLAUDIO_WITH_WHISPER.");
#endif
}

ofxGgmlAudioResult ofxGgmlAudioWhisperBackend::transcribe(const ofxGgmlAudioRequest& request) {
	if (!ofxGgmlAudioUtils::hasInput(request)) {
		return makeError("no audio path was configured");
	}
	if (!impl || !impl->isLoaded()) {
		return makeError("whisper.cpp context is not loaded");
	}

#if OFXGGMLAUDIO_HAS_WHISPER
	return makeError("whisper.cpp audio decoding is not wired yet; this backend boundary only owns runtime setup for now");
#else
	(void)request;
	return makeError("whisper.cpp backend is not enabled. Run scripts/build-whisper.*, then compile with OFXGGMLAUDIO_WITH_WHISPER.");
#endif
}

void ofxGgmlAudioWhisperBackend::close() {
	if (impl) {
		impl->close();
	}
}
