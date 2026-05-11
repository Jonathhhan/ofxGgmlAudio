#pragma once

#include "ofMain.h"
#include "ofxGgmlAudio.h"

class ofApp : public ofBaseApp {
public:
	void setup() override;
	void draw() override;

private:
	ofxGgmlAudioRequest request;
	std::string status;
};