#include "ofxGgmlAudioUtils.h"

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <fstream>
#include <limits>

namespace {
	constexpr int WavFormatPcm = 1;
	constexpr int WavFormatIeeeFloat = 3;

	void setError(std::string * error, const std::string & message) {
		if (error) {
			*error = message;
		}
	}

	bool hasText(const std::string & value) {
		return value.find_first_not_of(" \t\r\n") != std::string::npos;
	}

	bool readBytes(std::ifstream & input, char * data, std::streamsize size) {
		input.read(data, size);
		return input.good() || input.gcount() == size;
	}

	std::uint16_t readU16(const unsigned char * data) {
		return static_cast<std::uint16_t>(data[0]) |
			(static_cast<std::uint16_t>(data[1]) << 8);
	}

	std::uint32_t readU32(const unsigned char * data) {
		return static_cast<std::uint32_t>(data[0]) |
			(static_cast<std::uint32_t>(data[1]) << 8) |
			(static_cast<std::uint32_t>(data[2]) << 16) |
			(static_cast<std::uint32_t>(data[3]) << 24);
	}

	std::int16_t readI16(const unsigned char * data) {
		return static_cast<std::int16_t>(readU16(data));
	}

	float readF32(const unsigned char * data) {
		float value = 0.0f;
		static_assert(sizeof(value) == 4, "float must be 32-bit");
		std::memcpy(&value, data, sizeof(value));
		return value;
	}

	bool skipChunkPadding(std::ifstream & input, std::uint32_t chunkSize) {
		if ((chunkSize % 2) == 0) {
			return true;
		}
		input.seekg(1, std::ios::cur);
		return static_cast<bool>(input);
	}
}

namespace ofxGgmlAudioUtils {
	bool hasInput(const ofxGgmlAudioRequest & request) {
		return hasText(request.audioPath);
	}

	bool hasSamples(const ofxGgmlAudioStreamRequest & request) {
		return request.format.isValid() &&
			!request.samples.empty() &&
			(request.samples.size() % static_cast<std::size_t>(request.format.channels)) == 0;
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

	bool mixToMono(const ofxGgmlAudioStreamRequest & request, std::vector<float> & samples, std::string * error) {
		samples.clear();
		if (!request.format.isValid()) {
			setError(error, "audio stream request has an invalid format");
			return false;
		}
		if (request.samples.empty()) {
			setError(error, "audio stream request has no samples");
			return false;
		}
		if ((request.samples.size() % static_cast<std::size_t>(request.format.channels)) != 0) {
			setError(error, "audio stream sample count is not aligned to the channel count");
			return false;
		}

		const auto frameCount = getFrameCount(request);
		if (frameCount <= 0) {
			setError(error, "audio stream request has no complete frames");
			return false;
		}

		samples.resize(static_cast<std::size_t>(frameCount));
		if (request.format.channels == 1) {
			std::copy_n(request.samples.begin(), static_cast<std::size_t>(frameCount), samples.begin());
			return true;
		}

		for (int frame = 0; frame < frameCount; ++frame) {
			float mixed = 0.0f;
			for (int channel = 0; channel < request.format.channels; ++channel) {
				const auto index = static_cast<std::size_t>(frame * request.format.channels + channel);
				mixed += request.samples[index];
			}
			samples[static_cast<std::size_t>(frame)] = mixed / static_cast<float>(request.format.channels);
		}
		return true;
	}

	bool resampleMono(const std::vector<float> & input, int sourceSampleRate, int targetSampleRate, std::vector<float> & output, std::string * error) {
		output.clear();
		if (input.empty()) {
			setError(error, "cannot resample empty audio");
			return false;
		}
		if (sourceSampleRate <= 0 || targetSampleRate <= 0) {
			setError(error, "cannot resample audio with invalid sample rates");
			return false;
		}
		if (sourceSampleRate == targetSampleRate) {
			output = input;
			return true;
		}

		const auto outputSize = static_cast<std::size_t>(std::max(
			1.0,
			std::round(static_cast<double>(input.size()) *
				static_cast<double>(targetSampleRate) /
				static_cast<double>(sourceSampleRate))));
		output.resize(outputSize);
		const double sourceStep = static_cast<double>(sourceSampleRate) /
			static_cast<double>(targetSampleRate);

		for (std::size_t i = 0; i < output.size(); ++i) {
			const double sourcePosition = static_cast<double>(i) * sourceStep;
			const auto index = static_cast<std::size_t>(sourcePosition);
			const auto nextIndex = std::min(index + 1, input.size() - 1);
			const float fraction = static_cast<float>(sourcePosition - static_cast<double>(index));
			const float current = input[std::min(index, input.size() - 1)];
			const float next = input[nextIndex];
			output[i] = current + ((next - current) * fraction);
		}
		return true;
	}

	bool loadWavFile(const std::string & path, ofxGgmlAudioFrame & frame, ofxGgmlAudioWavInfo * info, std::string * error) {
		frame = ofxGgmlAudioFrame{};
		if (info) {
			*info = ofxGgmlAudioWavInfo{};
		}
		if (!hasText(path)) {
			setError(error, "audio path is empty");
			return false;
		}

		std::ifstream input(path, std::ios::binary);
		if (!input) {
			setError(error, "could not open WAV file: " + path);
			return false;
		}

		char riffHeader[12] = {};
		if (!readBytes(input, riffHeader, sizeof(riffHeader)) ||
			std::strncmp(riffHeader, "RIFF", 4) != 0 ||
			std::strncmp(riffHeader + 8, "WAVE", 4) != 0) {
			setError(error, "file is not a RIFF/WAVE file");
			return false;
		}

		bool foundFormat = false;
		bool foundData = false;
		int formatCode = 0;
		int channels = 0;
		int sampleRate = 0;
		int bitsPerSample = 0;
		std::vector<unsigned char> dataBytes;

		while (input) {
			char chunkHeader[8] = {};
			if (!readBytes(input, chunkHeader, sizeof(chunkHeader))) {
				break;
			}
			const auto chunkSize = readU32(reinterpret_cast<const unsigned char *>(chunkHeader + 4));
			const std::string chunkId(chunkHeader, chunkHeader + 4);

			if (chunkId == "fmt ") {
				std::vector<unsigned char> formatBytes(chunkSize);
				if (!formatBytes.empty() && !readBytes(input, reinterpret_cast<char *>(formatBytes.data()), static_cast<std::streamsize>(formatBytes.size()))) {
					setError(error, "could not read WAV fmt chunk");
					return false;
				}
				if (formatBytes.size() < 16) {
					setError(error, "WAV fmt chunk is too small");
					return false;
				}
				formatCode = readU16(formatBytes.data());
				channels = readU16(formatBytes.data() + 2);
				sampleRate = static_cast<int>(readU32(formatBytes.data() + 4));
				bitsPerSample = readU16(formatBytes.data() + 14);
				foundFormat = true;
				if (!skipChunkPadding(input, chunkSize)) {
					setError(error, "could not skip WAV fmt padding");
					return false;
				}
			} else if (chunkId == "data") {
				dataBytes.resize(chunkSize);
				if (!dataBytes.empty() && !readBytes(input, reinterpret_cast<char *>(dataBytes.data()), static_cast<std::streamsize>(dataBytes.size()))) {
					setError(error, "could not read WAV data chunk");
					return false;
				}
				foundData = true;
				if (!skipChunkPadding(input, chunkSize)) {
					setError(error, "could not skip WAV data padding");
					return false;
				}
			} else {
				input.seekg(chunkSize + (chunkSize % 2), std::ios::cur);
				if (!input) {
					setError(error, "could not skip WAV chunk: " + chunkId);
					return false;
				}
			}
		}

		if (!foundFormat || !foundData) {
			setError(error, "WAV file is missing fmt or data chunks");
			return false;
		}
		if (channels <= 0 || sampleRate <= 0) {
			setError(error, "WAV file has invalid channel count or sample rate");
			return false;
		}
		if (!((formatCode == WavFormatPcm && bitsPerSample == 16) ||
			(formatCode == WavFormatIeeeFloat && bitsPerSample == 32))) {
			setError(error, "only 16-bit PCM and 32-bit float WAV files are supported");
			return false;
		}

		const int bytesPerSample = bitsPerSample / 8;
		const auto totalSamples = dataBytes.size() / static_cast<std::size_t>(bytesPerSample);
		if (totalSamples == 0 || totalSamples > static_cast<std::size_t>(std::numeric_limits<int>::max())) {
			setError(error, "WAV file has no supported sample data");
			return false;
		}
		if ((totalSamples % static_cast<std::size_t>(channels)) != 0) {
			setError(error, "WAV sample count is not aligned to the channel count");
			return false;
		}

		frame.format.sampleRate = sampleRate;
		frame.format.channels = channels;
		frame.samples.resize(totalSamples);
		for (std::size_t i = 0; i < totalSamples; ++i) {
			const auto * sampleData = dataBytes.data() + (i * static_cast<std::size_t>(bytesPerSample));
			if (formatCode == WavFormatPcm) {
				frame.samples[i] = static_cast<float>(readI16(sampleData)) / 32768.0f;
			} else {
				frame.samples[i] = readF32(sampleData);
			}
		}

		if (info) {
			info->format = frame.format;
			info->bitsPerSample = bitsPerSample;
			info->formatCode = formatCode;
			info->frameCount = totalSamples / static_cast<std::size_t>(channels);
		}
		return true;
	}

	ofxGgmlAudioStreamRequest toStreamRequest(const ofxGgmlAudioFrame & frame, ofxGgmlAudioTask task) {
		ofxGgmlAudioStreamRequest request;
		request.task = task;
		request.format = frame.format;
		request.samples = frame.samples;
		request.timestampSeconds = frame.timestampSeconds;
		return request;
	}
}
