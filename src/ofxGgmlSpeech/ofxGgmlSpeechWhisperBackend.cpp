#include "ofxGgmlSpeechWhisperBackend.h"

#include "ofxGgmlSpeechUtils.h"

#if defined(OFXGGMLSPEECH_WITH_WHISPER) && __has_include(<whisper.h>)
	#include <whisper.h>
	#define OFXGGMLSPEECH_HAS_WHISPER 1
#else
	#define OFXGGMLSPEECH_HAS_WHISPER 0
#endif

namespace {
	ofxGgmlSpeechResult makeError(const std::string& message) {
		ofxGgmlSpeechResult result;
		result.success = false;
		result.error = message;
		return result;
	}

	ofxGgmlSpeechResult makeOk(const std::string& message) {
		ofxGgmlSpeechResult result;
		result.success = true;
		result.text = message;
		return result;
	}
}

struct ofxGgmlSpeechWhisperBackend::Impl {
	ofxGgmlSpeechWhisperSettings settings;
#if OFXGGMLSPEECH_HAS_WHISPER
	whisper_context* context = nullptr;
#endif

	~Impl() {
		close();
	}

	bool isAvailable() const {
		return OFXGGMLSPEECH_HAS_WHISPER != 0;
	}

	bool isLoaded() const {
#if OFXGGMLSPEECH_HAS_WHISPER
		return context != nullptr;
#else
		return false;
#endif
	}

	void close() {
#if OFXGGMLSPEECH_HAS_WHISPER
		if (context) {
			whisper_free(context);
			context = nullptr;
		}
#endif
	}
};

ofxGgmlSpeechWhisperBackend::ofxGgmlSpeechWhisperBackend()
	: impl(std::make_unique<Impl>()) {
}

ofxGgmlSpeechWhisperBackend::~ofxGgmlSpeechWhisperBackend() = default;
ofxGgmlSpeechWhisperBackend::ofxGgmlSpeechWhisperBackend(ofxGgmlSpeechWhisperBackend&& other) noexcept = default;
ofxGgmlSpeechWhisperBackend& ofxGgmlSpeechWhisperBackend::operator=(ofxGgmlSpeechWhisperBackend&& other) noexcept = default;

bool ofxGgmlSpeechWhisperBackend::isAvailable() const {
	return impl && impl->isAvailable();
}

bool ofxGgmlSpeechWhisperBackend::isLoaded() const {
	return impl && impl->isLoaded();
}

std::string ofxGgmlSpeechWhisperBackend::getBackendName() const {
	return "whisper.cpp";
}

ofxGgmlSpeechWhisperSettings ofxGgmlSpeechWhisperBackend::getSettings() const {
	return impl ? impl->settings : ofxGgmlSpeechWhisperSettings{};
}

ofxGgmlSpeechResult ofxGgmlSpeechWhisperBackend::setup(const ofxGgmlSpeechWhisperSettings& settings) {
	if (!impl) {
		return makeError("whisper backend is not initialized");
	}
	impl->close();
	impl->settings = settings;

#if OFXGGMLSPEECH_HAS_WHISPER
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
	return makeError("whisper.cpp backend is not enabled. Run scripts/build-whisper.*, then compile with OFXGGMLSPEECH_WITH_WHISPER.");
#endif
}

ofxGgmlSpeechResult ofxGgmlSpeechWhisperBackend::transcribe(const ofxGgmlSpeechRequest& request) {
	if (!ofxGgmlSpeechUtils::hasInput(request)) {
		return makeError("no audio path was configured");
	}
	if (!impl || !impl->isLoaded()) {
		return makeError("whisper.cpp context is not loaded");
	}

#if OFXGGMLSPEECH_HAS_WHISPER
	return makeError("whisper.cpp audio decoding is not wired yet; this backend boundary only owns runtime setup for now");
#else
	(void)request;
	return makeError("whisper.cpp backend is not enabled. Run scripts/build-whisper.*, then compile with OFXGGMLSPEECH_WITH_WHISPER.");
#endif
}

void ofxGgmlSpeechWhisperBackend::close() {
	if (impl) {
		impl->close();
	}
}
