#pragma once

#include <string>
#include <vector>

struct ofxGgmlAudioRequest {
	std::string audioPath;
	std::string language;
	std::vector<std::string> tags;
};

struct ofxGgmlAudioResult {
	bool success = false;
	std::string text;
	std::string error;
	std::vector<std::string> references;

	explicit operator bool() const {
		return success;
	}
};