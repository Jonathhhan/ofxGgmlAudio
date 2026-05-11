#include "ofxGgmlAudioFeatures.h"

#include <algorithm>
#include <cmath>

namespace {
	ofxGgmlAudioFeatureFrame analyzeSamples(
		const ofxGgmlAudioStreamFormat & format,
		const std::vector<float> & samples,
		double timestampSeconds) {
		ofxGgmlAudioFeatureFrame features;
		features.format = format;
		features.timestampSeconds = timestampSeconds;

		if (!format.isValid() || samples.empty()) {
			return features;
		}

		double sum = 0.0;
		double sumSquares = 0.0;
		float peak = 0.0f;
		int zeroCrossings = 0;
		float previous = samples.front();

		for (std::size_t i = 0; i < samples.size(); ++i) {
			const auto sample = samples[i];
			sum += static_cast<double>(sample);
			sumSquares += static_cast<double>(sample) * static_cast<double>(sample);
			peak = std::max(peak, std::abs(sample));

			if (i > 0 &&
				((previous < 0.0f && sample >= 0.0f) ||
					(previous >= 0.0f && sample < 0.0f))) {
				zeroCrossings++;
			}
			previous = sample;
		}

		const auto sampleCount = static_cast<double>(samples.size());
		features.mean = static_cast<float>(sum / sampleCount);
		features.rms = static_cast<float>(std::sqrt(sumSquares / sampleCount));
		features.peak = peak;
		features.zeroCrossingRate = samples.size() > 1
			? static_cast<float>(static_cast<double>(zeroCrossings) /
				static_cast<double>(samples.size() - 1))
			: 0.0f;

		const auto channels = std::max(1, format.channels);
		const auto frameCount = static_cast<int>(samples.size() / static_cast<std::size_t>(channels));
		features.durationSeconds = format.sampleRate > 0
			? static_cast<double>(frameCount) / static_cast<double>(format.sampleRate)
			: 0.0;
		return features;
	}
}

namespace ofxGgmlAudioFeatures {
	ofxGgmlAudioFeatureFrame analyze(const ofxGgmlAudioStreamRequest & request) {
		return analyzeSamples(request.format, request.samples, request.timestampSeconds);
	}

	ofxGgmlAudioFeatureFrame analyze(const ofxGgmlAudioFrame & frame) {
		return analyzeSamples(frame.format, frame.samples, frame.timestampSeconds);
	}

	bool isProbablySilent(const ofxGgmlAudioFeatureFrame & features, float rmsThreshold) {
		return features.rms < rmsThreshold;
	}

	std::vector<float> toVector(const ofxGgmlAudioFeatureFrame & features) {
		return {
			features.rms,
			features.peak,
			features.zeroCrossingRate,
			features.mean
		};
	}
}
