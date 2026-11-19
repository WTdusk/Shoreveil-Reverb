#pragma once

#include "dsp/ReverbEngine.h"

#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdio>
#include <utility>
#include <vector>

namespace rivage
{
inline bool measureInterruptedTail (double sampleRate, int blockSize)
{
    ReverbEngine switched, reference;
    ReverbParameters params;
    params.algorithm = 0; // Room
    params.mix = 1.0f;
    params.decay = 0.9f;
    params.predelay = 0.0f;
    for (auto* engine : { &switched, &reference })
    {
        engine->setParameters (params);
        engine->prepare (sampleRate, blockSize);
    }

    juce::AudioBuffer<float> wet (2, blockSize), continued (2, blockSize);
    juce::Random noise (12345);
    for (int block = 0; block < juce::roundToInt (sampleRate / blockSize); ++block)
    {
        for (int sample = 0; sample < blockSize; ++sample)
        {
            const float input = (noise.nextFloat() - 0.5f) * 0.12f;
            wet.setSample (0, sample, input);
            wet.setSample (1, sample, input);
        }
        continued.makeCopyOf (wet, true);
        switched.process (wet);
        reference.process (continued);
    }

    params.algorithm = 2; // Hall
    switched.setParameters (params);
    reference.setParameters (params);
    const int holdBlocks = juce::roundToInt (0.020 * sampleRate / blockSize);
    for (int block = 0; block < holdBlocks; ++block)
    {
        wet.clear();
        continued.clear();
        switched.process (wet);
        reference.process (continued);
    }

    const std::array<float, 2> last { wet.getSample (0, blockSize - 1), wet.getSample (1, blockSize - 1) };
    params.algorithm = 5; // Cloud
    switched.setParameters (params);
    wet.clear();
    continued.clear();
    switched.process (wet);
    reference.process (continued);

    double interruption = 0.0, switchedStep = 0.0, referenceStep = 0.0;
    bool finite = true;
    for (int channel = 0; channel < 2; ++channel)
    {
        const float switchedSample = wet.getSample (channel, 0);
        const float referenceSample = continued.getSample (channel, 0);
        finite = finite && std::isfinite (switchedSample) && std::isfinite (referenceSample);
        interruption = std::max (interruption, (double) std::abs (switchedSample - referenceSample));
        switchedStep = std::max (switchedStep, (double) std::abs (switchedSample - last[(size_t) channel]));
        referenceStep = std::max (referenceStep, (double) std::abs (referenceSample - last[(size_t) channel]));
    }

    std::printf ("  tail-only Room -> Hall -> Cloud: new step=%.6f, uninterrupted step=%.6f, first sample delta=%.6f\n",
                 switchedStep, referenceStep, interruption);
    return finite;
}

inline int runRapidSwitchChecks()
{
    using Clock = std::chrono::steady_clock;
    juce::ScopedNoDenormals noDenormals;
    bool finite = true;

    for (const auto& [sampleRate, blockSize] : { std::pair { 48000.0, 64 }, std::pair { 96000.0, 32 } })
    {
        const double budgetUs = 1.0e6 * blockSize / sampleRate;
        const int switchInterval = juce::roundToInt (0.020 * sampleRate / blockSize);
        const int warmupBlocks = juce::roundToInt (sampleRate / blockSize);
        const int measuredBlocks = 150 * switchInterval;

        for (bool springOnly : { false, true })
        {
            const std::array<int, kNumEngines> order { 0, 4, 2, 6, 5, 1, 3 };
            auto modeFor = [&] (int index)
            {
                return springOnly ? (index % 2 == 0 ? kSpringAlgorithmIndex : kSpringTankEngine)
                                  : order[(size_t) (index % kNumEngines)];
            };
            ReverbEngine engine;
            ReverbParameters params;
            params.mix = 1.0f;
            params.decay = 0.75f;
            params.predelay = 0.0f;
            params.algorithm = modeFor (0);
            engine.setParameters (params);
            engine.prepare (sampleRate, blockSize);
            juce::AudioBuffer<float> buffer (2, blockSize);
            juce::Random random (12345);
            std::array<float, 2> previous {}, previousBefore {};
            std::vector<double> switchTimes, steadyTimes;
            switchTimes.reserve (150);
            steadyTimes.reserve ((size_t) measuredBlocks - 150);
            double worstJump = 0.0;
            double worstExcess = 0.0;
            int worstFrom = modeFor (0), worstTo = modeFor (0);

            for (int block = -warmupBlocks; block < measuredBlocks; ++block)
            {
                for (int sample = 0; sample < blockSize; ++sample)
                {
                    const float input = (random.nextFloat() - 0.5f) * 0.12f;
                    buffer.setSample (0, sample, input);
                    buffer.setSample (1, sample, input * 0.8f);
                }

                const bool switching = block >= 0 && block % switchInterval == 0;
                const int switchIndex = switching ? block / switchInterval : 0;
                if (switching)
                {
                    const int next = modeFor (switchIndex + 1);
                    params.algorithm = next == kSpringTankEngine ? kSpringAlgorithmIndex : next;
                    params.springModel = next == kSpringTankEngine ? 1 : 0;
                }

                const auto start = Clock::now();
                engine.setParameters (params);
                engine.process (buffer);
                const double elapsed = std::chrono::duration<double, std::micro> (Clock::now() - start).count();
                if (block >= 0)
                    (switching ? switchTimes : steadyTimes).push_back (elapsed);

                for (int channel = 0; channel < 2; ++channel)
                {
                    const auto* output = buffer.getReadPointer (channel);
                    finite = finite && std::all_of (output, output + blockSize, [] (float value) { return std::isfinite (value); });
                    auto& last = previous[(size_t) channel];
                    auto& beforeLast = previousBefore[(size_t) channel];
                    if (switching)
                    {
                        const double jump = std::abs (output[0] - last);
                        double nearby = std::abs (last - beforeLast);
                        for (int i = 1; i <= 8; ++i)
                            nearby = std::max (nearby, (double) std::abs (output[i] - output[i - 1]));

                        const double excess = jump - nearby;
                        if (excess > worstExcess)
                        {
                            worstExcess = excess;
                            worstFrom = modeFor (switchIndex);
                            worstTo = modeFor (switchIndex + 1);
                        }

                        worstJump = std::max (worstJump, jump);
                    }
                    beforeLast = output[blockSize - 2];
                    last = output[blockSize - 1];
                }
            }

            auto report = [budgetUs] (const char* label, std::vector<double>& times)
            {
                std::sort (times.begin(), times.end());
                const auto p99 = times[(99 * times.size() + 99) / 100 - 1];
                const auto overBudget = times.end() - std::upper_bound (times.begin(), times.end(), budgetUs);
                std::printf ("  %-6s p99=%7.2f us max=%7.2f us over=%td/%zu\n",
                             label, p99, times.back(), overBudget, times.size());
            };
            std::printf ("%.0f Hz / %d samples, %s, block budget %.2f us\n",
                         sampleRate, blockSize, springOnly ? "PURE/TANK" : "seven engines", budgetUs);
            report ("switch", switchTimes);
            report ("steady", steadyTimes);
            std::printf ("  max wet step=%.6f  max excess over neighbors=%.6f (%s -> %s)\n",
                         worstJump, worstExcess, algorithmName (worstFrom), algorithmName (worstTo));
        }

        finite = measureInterruptedTail (sampleRate, blockSize) && finite;
    }

    std::printf ("rapidcheck: %s (timing and continuity figures are diagnostic)\n",
                 finite ? "finite output" : "non-finite output");
    return finite ? 0 : 1;
}
} // namespace rivage
