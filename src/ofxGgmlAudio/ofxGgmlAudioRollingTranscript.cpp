#include "ofxGgmlAudioRollingTranscript.h"

#include "ofxGgmlAudioUtils.h"

#include <algorithm>
#include <cmath>
#include <sstream>

namespace {
	std::string trimText(const std::string & value) {
		const auto first = value.find_first_not_of(" \t\r\n");
		if (first == std::string::npos) {
			return "";
		}
		const auto last = value.find_last_not_of(" \t\r\n");
		return value.substr(first, last - first + 1);
	}

	bool isUsableSegment(const ofxGgmlAudioTranscriptSegment & segment) {
		return !trimText(segment.text).empty() &&
			std::isfinite(segment.startSeconds) &&
			std::isfinite(segment.endSeconds);
	}
}

ofxGgmlAudioRollingTranscript::ofxGgmlAudioRollingTranscript(
	const ofxGgmlAudioRollingTranscriptSettings & settings)
	: settings(settings) {
}

void ofxGgmlAudioRollingTranscript::setup(
	const ofxGgmlAudioRollingTranscriptSettings & settings) {
	this->settings = settings;
}

const ofxGgmlAudioRollingTranscriptSettings & ofxGgmlAudioRollingTranscript::getSettings() const {
	return settings;
}

void ofxGgmlAudioRollingTranscript::clear() {
	segments.clear();
}

bool ofxGgmlAudioRollingTranscript::empty() const {
	return segments.empty();
}

std::size_t ofxGgmlAudioRollingTranscript::size() const {
	return segments.size();
}

bool ofxGgmlAudioRollingTranscript::addSegment(
	const ofxGgmlAudioTranscriptSegment & segment) {
	if (!isUsableSegment(segment) || isDuplicate(segment)) {
		return false;
	}

	auto normalized = segment;
	normalized.text = trimText(normalized.text);
	if (normalized.endSeconds < normalized.startSeconds) {
		normalized.endSeconds = normalized.startSeconds;
	}
	segments.push_back(normalized);
	sortSegments();
	return true;
}

int ofxGgmlAudioRollingTranscript::addSegments(
	const std::vector<ofxGgmlAudioTranscriptSegment> & segments) {
	int added = 0;
	for (const auto & segment : segments) {
		added += addSegment(segment) ? 1 : 0;
	}
	return added;
}

int ofxGgmlAudioRollingTranscript::addResult(const ofxGgmlAudioResult & result) {
	return addSegments(result.segments);
}

int ofxGgmlAudioRollingTranscript::addResult(const ofxGgmlAudioStreamResult & result) {
	return addSegments(result.segments);
}

const std::vector<ofxGgmlAudioTranscriptSegment> & ofxGgmlAudioRollingTranscript::getSegments() const {
	return segments;
}

std::string ofxGgmlAudioRollingTranscript::getText() const {
	std::ostringstream output;
	for (std::size_t i = 0; i < segments.size(); ++i) {
		if (i > 0) {
			output << '\n';
		}
		output << segments[i].text;
	}
	return output.str();
}

std::string ofxGgmlAudioRollingTranscript::buildSrt() const {
	return ofxGgmlAudioUtils::buildSrt(segments);
}

std::string ofxGgmlAudioRollingTranscript::buildWebVtt() const {
	return ofxGgmlAudioUtils::buildWebVtt(segments);
}

bool ofxGgmlAudioRollingTranscript::isDuplicate(
	const ofxGgmlAudioTranscriptSegment & segment) const {
	const auto text = trimText(segment.text);
	const auto tolerance = std::max(0.0, settings.duplicateTimeToleranceSeconds);
	for (const auto & existing : segments) {
		if (existing.text == text &&
			std::abs(existing.startSeconds - segment.startSeconds) <= tolerance &&
			std::abs(existing.endSeconds - segment.endSeconds) <= tolerance) {
			return true;
		}
	}
	return false;
}

void ofxGgmlAudioRollingTranscript::sortSegments() {
	std::sort(segments.begin(), segments.end(), [](const auto & a, const auto & b) {
		if (a.startSeconds == b.startSeconds) {
			return a.endSeconds < b.endSeconds;
		}
		return a.startSeconds < b.startSeconds;
	});
}
