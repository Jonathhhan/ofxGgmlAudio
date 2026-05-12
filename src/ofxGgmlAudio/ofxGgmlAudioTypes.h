#pragma once

#include <cstddef>
#include <string>
#include <vector>

enum class ofxGgmlAudioTask {
	Transcription,
	Denoising,
	VoiceConversion,
	EmotionDetection,
	VoiceActivityDetection,
	AudioEventDetection
};

struct ofxGgmlAudioStreamFormat {
	int sampleRate = 16000;
	int channels = 1;

	bool isValid() const {
		return sampleRate > 0 && channels > 0;
	}
};

struct ofxGgmlAudioFrame {
	ofxGgmlAudioStreamFormat format;
	std::vector<float> samples;
	double timestampSeconds = 0.0;

	int getFrameCount() const {
		if (format.channels <= 0) {
			return 0;
		}
		return static_cast<int>(samples.size() / static_cast<std::size_t>(format.channels));
	}
};

struct ofxGgmlAudioWavInfo {
	ofxGgmlAudioStreamFormat format;
	int bitsPerSample = 0;
	int formatCode = 0;
	std::size_t frameCount = 0;
};

struct ofxGgmlAudioRequest {
	std::string audioPath;
	std::string language;
	std::vector<std::string> tags;
};

struct ofxGgmlAudioTranscriptSegment {
	double startSeconds = 0.0;
	double endSeconds = 0.0;
	std::string text;
	float confidence = 0.0f;
};

struct ofxGgmlAudioStreamRequest {
	ofxGgmlAudioTask task = ofxGgmlAudioTask::Transcription;
	ofxGgmlAudioStreamFormat format;
	std::vector<float> samples;
	double timestampSeconds = 0.0;
	std::string modelPath;
	std::string voiceId;
	std::vector<std::string> hints;
};

struct ofxGgmlAudioResult {
	bool success = false;
	std::string text;
	std::string error;
	std::vector<ofxGgmlAudioTranscriptSegment> segments;
	std::vector<std::string> references;

	explicit operator bool() const {
		return success;
	}
};

struct ofxGgmlAudioStreamResult {
	bool success = false;
	ofxGgmlAudioTask task = ofxGgmlAudioTask::Transcription;
	double timestampSeconds = 0.0;
	double durationSeconds = 0.0;
	std::string label;
	std::string text;
	std::string error;
	std::vector<ofxGgmlAudioTranscriptSegment> segments;
	std::vector<float> samples;
	std::vector<float> scores;

	explicit operator bool() const {
		return success;
	}
};
