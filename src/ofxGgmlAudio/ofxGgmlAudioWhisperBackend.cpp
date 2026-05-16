#include "ofxGgmlAudioWhisperBackend.h"

#include "ofxGgmlAudioUtils.h"

#include <algorithm>
#include <cctype>
#include <sstream>
#include <thread>
#include <vector>

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

	bool getMono16kSamples(const ofxGgmlAudioStreamRequest& request, std::vector<float>& samples, std::string& error) {
		if (request.task != ofxGgmlAudioTask::Transcription) {
			error = "whisper.cpp only handles transcription requests";
			return false;
		}

		std::vector<float> monoSamples;
		if (!ofxGgmlAudioUtils::mixToMono(request, monoSamples, &error)) {
			return false;
		}
		return ofxGgmlAudioUtils::resampleMono(monoSamples, request.format.sampleRate, 16000, samples, &error);
	}

	std::string upperText(std::string value) {
		std::transform(value.begin(), value.end(), value.begin(), [](unsigned char c) {
			return static_cast<char>(std::toupper(c));
		});
		return value;
	}

	bool systemFlagEnabled(const std::string& systemInfo, const std::string& name) {
		const auto text = upperText(systemInfo);
		const auto flag = upperText(name);
		return text.find(flag + " = 1") != std::string::npos ||
			text.find(flag + "=1") != std::string::npos ||
			text.find(flag + " : 1") != std::string::npos ||
			text.find(flag + ":1") != std::string::npos;
	}

	std::string describeAcceleration(const std::string& systemInfo) {
		std::vector<std::string> enabled;
		for (const auto& name : { "CUDA", "METAL", "VULKAN", "OPENCL", "COREML", "OPENVINO" }) {
			if (systemFlagEnabled(systemInfo, name)) {
				enabled.push_back(name);
			}
		}
		if (enabled.empty()) {
			return "CPU";
		}
		std::ostringstream stream;
		stream << "CPU";
		for (const auto& name : enabled) {
			stream << " + " << name;
		}
		return stream.str();
	}

	bool hasGpuAcceleration(const std::string& systemInfo) {
		for (const auto& name : { "CUDA", "METAL", "VULKAN", "OPENCL", "COREML", "OPENVINO" }) {
			if (systemFlagEnabled(systemInfo, name)) {
				return true;
			}
		}
		return false;
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

ofxGgmlAudioWhisperRuntimeInfo ofxGgmlAudioWhisperBackend::getRuntimeInfo() const {
	ofxGgmlAudioWhisperRuntimeInfo info;
	info.compiled = isAvailable();
	info.loaded = isLoaded();
	if (!impl) {
		return info;
	}
	info.configuredThreads = impl->settings.threads;
	const auto hardwareThreads = static_cast<int>(std::thread::hardware_concurrency());
	info.effectiveThreads = impl->settings.threads > 0 ? impl->settings.threads : std::max(1, hardwareThreads);
	info.modelPath = impl->settings.modelPath;
#if OFXGGMLAUDIO_HAS_WHISPER
	whisper_context_params params = whisper_context_default_params();
	info.gpuRequested = params.use_gpu;
	const char* systemInfo = whisper_print_system_info();
	info.systemInfo = systemInfo ? systemInfo : "";
	info.gpuAvailable = hasGpuAcceleration(info.systemInfo);
	info.acceleration = describeAcceleration(info.systemInfo);
#else
	info.acceleration = "unavailable";
#endif
	return info;
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

	ofxGgmlAudioFrame frame;
	std::string loadError;
	if (!ofxGgmlAudioUtils::loadWavFile(request.audioPath, frame, nullptr, &loadError)) {
		return makeError(loadError);
	}

	auto streamRequest = ofxGgmlAudioUtils::toStreamRequest(frame, ofxGgmlAudioTask::Transcription);
	if (!request.language.empty()) {
		streamRequest.hints.push_back("language:" + request.language);
	}
	return transcribe(streamRequest);
}

ofxGgmlAudioResult ofxGgmlAudioWhisperBackend::transcribe(const ofxGgmlAudioStreamRequest& request) {
	std::vector<float> samples;
	std::string pcmError;
	if (!getMono16kSamples(request, samples, pcmError)) {
		return makeError(pcmError);
	}
	if (!impl || !impl->isLoaded()) {
		return makeError("whisper.cpp context is not loaded");
	}

#if OFXGGMLAUDIO_HAS_WHISPER
	auto params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
	const auto hardwareThreads = static_cast<int>(std::thread::hardware_concurrency());
	params.n_threads = impl->settings.threads > 0 ? impl->settings.threads : std::max(1, hardwareThreads);
	params.translate = impl->settings.translate;
	params.no_timestamps = !impl->settings.timestamps;
	params.print_progress = false;
	params.print_realtime = false;
	params.print_timestamps = false;
	params.print_special = false;

	std::string language = impl->settings.language;
	for (const auto& hint : request.hints) {
		const std::string prefix = "language:";
		if (hint.rfind(prefix, 0) == 0) {
			language = hint.substr(prefix.size());
		}
	}
	if (!language.empty()) {
		params.language = language.c_str();
	}

	if (whisper_full(impl->context, params, samples.data(), static_cast<int>(samples.size())) != 0) {
		return makeError("whisper.cpp transcription failed");
	}

	ofxGgmlAudioResult result;
	result.success = true;
	const int segmentCount = whisper_full_n_segments(impl->context);
	std::ostringstream text;
	for (int i = 0; i < segmentCount; ++i) {
		if (i > 0) {
			text << '\n';
		}
		const char* segmentText = whisper_full_get_segment_text(impl->context, i);
		if (segmentText) {
			text << segmentText;
			const double segmentStart =
				request.timestampSeconds + (static_cast<double>(whisper_full_get_segment_t0(impl->context, i)) * 0.01);
			const double segmentEnd =
				request.timestampSeconds + (static_cast<double>(whisper_full_get_segment_t1(impl->context, i)) * 0.01);
			result.segments.push_back({ segmentStart, segmentEnd, segmentText, 0.0f });
		}
	}
	result.text = text.str();
	return result;
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
