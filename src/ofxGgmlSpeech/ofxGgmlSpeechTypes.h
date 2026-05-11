#pragma once

#include <string>
#include <vector>

struct ofxGgmlSpeechRequest {
	std::string audioPath;
	std::string language;
	std::vector<std::string> tags;
};

struct ofxGgmlSpeechResult {
	bool success = false;
	std::string text;
	std::string error;
	std::vector<std::string> references;

	explicit operator bool() const {
		return success;
	}
};