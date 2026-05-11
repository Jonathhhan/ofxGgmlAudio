#include "ofxGgmlAudioUtils.h"

namespace ofxGgmlAudioUtils {
	bool hasInput(const ofxGgmlAudioRequest & request) {
		return !request.audioPath.empty();
	}

	bool hasSamples(const ofxGgmlAudioStreamRequest & request) {
		return request.format.isValid() && !request.samples.empty();
	}

	int getFrameCount(const ofxGgmlAudioStreamRequest & request) {
		if (request.format.channels <= 0) {
			return 0;
		}
		return static_cast<int>(request.samples.size() / static_cast<std::size_t>(request.format.channels));
	}

	double getDurationSeconds(const ofxGgmlAudioStreamRequest & request) {
		if (request.format.sampleRate <= 0) {
			return 0.0;
		}
		return static_cast<double>(getFrameCount(request)) /
			static_cast<double>(request.format.sampleRate);
	}

	std::string getTaskName(ofxGgmlAudioTask task) {
		switch (task) {
		case ofxGgmlAudioTask::Transcription:
			return "transcription";
		case ofxGgmlAudioTask::Denoising:
			return "denoising";
		case ofxGgmlAudioTask::VoiceConversion:
			return "voice conversion";
		case ofxGgmlAudioTask::EmotionDetection:
			return "emotion detection";
		case ofxGgmlAudioTask::VoiceActivityDetection:
			return "voice activity detection";
		case ofxGgmlAudioTask::AudioEventDetection:
			return "audio event detection";
		default:
			return "audio";
		}
	}

	std::string describe(const ofxGgmlAudioRequest & request) {
		if (!hasInput(request)) {
			return "audio: empty request";
		}
		return "audio: " + request.audioPath;
	}

	std::string describe(const ofxGgmlAudioStreamRequest & request) {
		if (!hasSamples(request)) {
			return "audio stream: empty request";
		}
		return getTaskName(request.task) + ": " +
			std::to_string(getFrameCount(request)) + " frames at " +
			std::to_string(request.format.sampleRate) + " Hz";
	}
}
