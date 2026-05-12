#pragma once

#include "ofxGgmlAudioTypes.h"

#include <string>

namespace ofxGgmlAudioUtils {
	bool hasInput(const ofxGgmlAudioRequest & request);
	bool hasSamples(const ofxGgmlAudioStreamRequest & request);
	int getFrameCount(const ofxGgmlAudioStreamRequest & request);
	double getDurationSeconds(const ofxGgmlAudioStreamRequest & request);
	std::string getTaskName(ofxGgmlAudioTask task);
	std::string describe(const ofxGgmlAudioRequest & request);
	std::string describe(const ofxGgmlAudioStreamRequest & request);
	bool mixToMono(const ofxGgmlAudioStreamRequest & request, std::vector<float> & samples, std::string * error = nullptr);
	bool resampleMono(const std::vector<float> & input, int sourceSampleRate, int targetSampleRate, std::vector<float> & output, std::string * error = nullptr);
	bool loadWavFile(const std::string & path, ofxGgmlAudioFrame & frame, ofxGgmlAudioWavInfo * info = nullptr, std::string * error = nullptr);
	ofxGgmlAudioStreamRequest toStreamRequest(const ofxGgmlAudioFrame & frame, ofxGgmlAudioTask task = ofxGgmlAudioTask::Transcription);
	std::string formatSubtitleTimestamp(double seconds, bool commaMilliseconds = false);
	std::string buildSrt(const std::vector<ofxGgmlAudioTranscriptSegment> & segments);
	std::string buildWebVtt(const std::vector<ofxGgmlAudioTranscriptSegment> & segments);
	bool writeSrtFile(const std::string & path, const std::vector<ofxGgmlAudioTranscriptSegment> & segments, std::string * error = nullptr);
	bool writeWebVttFile(const std::string & path, const std::vector<ofxGgmlAudioTranscriptSegment> & segments, std::string * error = nullptr);
}
