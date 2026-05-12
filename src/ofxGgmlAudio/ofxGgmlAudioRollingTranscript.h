#pragma once

#include "ofxGgmlAudioTypes.h"

#include <cstddef>
#include <string>
#include <vector>

struct ofxGgmlAudioRollingTranscriptSettings {
	double duplicateTimeToleranceSeconds = 0.25;
};

class ofxGgmlAudioRollingTranscript {
public:
	explicit ofxGgmlAudioRollingTranscript(
		const ofxGgmlAudioRollingTranscriptSettings & settings = {});

	void setup(const ofxGgmlAudioRollingTranscriptSettings & settings);
	const ofxGgmlAudioRollingTranscriptSettings & getSettings() const;

	void clear();
	bool empty() const;
	std::size_t size() const;

	bool addSegment(const ofxGgmlAudioTranscriptSegment & segment);
	int addSegments(const std::vector<ofxGgmlAudioTranscriptSegment> & segments);
	int addResult(const ofxGgmlAudioResult & result);
	int addResult(const ofxGgmlAudioStreamResult & result);

	const std::vector<ofxGgmlAudioTranscriptSegment> & getSegments() const;
	std::string getText() const;
	std::string buildSrt() const;
	std::string buildWebVtt() const;

private:
	bool isDuplicate(const ofxGgmlAudioTranscriptSegment & segment) const;
	void sortSegments();

	ofxGgmlAudioRollingTranscriptSettings settings;
	std::vector<ofxGgmlAudioTranscriptSegment> segments;
};
