// PCM Audio Processor for Web
// This file is used for audio processing in the web version of the app

class PCMProcessor extends AudioWorkletProcessor {
  constructor() {
    super();
    this.samples = [];
    this.bufferSize = 1024;
  }

  process(inputs, outputs, parameters) {
    const input = inputs[0];
    const output = outputs[0];

    if (input.length > 0) {
      const inputChannel = input[0];
      for (let i = 0; i < inputChannel.length; i++) {
        this.samples.push(inputChannel[i]);
      }

      // Process audio if we have enough samples
      if (this.samples.length >= this.bufferSize) {
        const processedSamples = this.samples.splice(0, this.bufferSize);
        
        // Send processed audio to main thread
        this.port.postMessage({
          type: 'audio-data',
          data: processedSamples
        });
      }

      // Pass through audio
      for (let channel = 0; channel < output.length; channel++) {
        for (let i = 0; i < output[channel].length; i++) {
          output[channel][i] = inputChannel[i] || 0;
        }
      }
    }

    return true;
  }
}

registerProcessor('pcm-processor', PCMProcessor); 