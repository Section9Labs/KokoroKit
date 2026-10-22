#!/usr/bin/env python3
"""Summarize saved device evidence without treating a partial run as a pass."""
import argparse
import json
from pathlib import Path


def summarize(report):
    events = report['events']
    generations = [e for e in events if e['kind'] == 'generationCompleted']
    first = [e['seconds'] for e in events if e['kind'] == 'firstAudio']
    audio_seconds = sum(e['samples'] / 24000 for e in generations)
    generation_seconds = sum(e['seconds'] for e in generations)
    locked_audio = [e for e in events if e['kind'] == 'audioGenerated'
                    and e['appState'] == 2 and not e['protectedDataAvailable']]
    locked_played = [e for e in events if e['kind'] == 'audioPlayed'
                     and e['appState'] == 2 and not e['protectedDataAvailable']]
    locked_starts = [e for e in events if e['kind'] == 'generationStarted'
                     and e['appState'] == 2 and not e['protectedDataAvailable']]
    locked_events = [e for e in events if e['appState'] == 2 and not e['protectedDataAvailable']]
    # Never bridge an intervening unlock when reporting locked observations.
    spans = []
    start = last = None
    for event in events:
        if event['appState'] == 2 and not event['protectedDataAvailable']:
            if start is None:
                start = event['elapsed']
            last = event['elapsed']
        elif start is not None:
            spans.append({'start': start, 'end': last, 'seconds': last - start})
            start = last = None
    if start is not None:
        spans.append({'start': start, 'end': last, 'seconds': last - start})
    underruns = [e['seconds'] for e in events if e['kind'] == 'playbackUnderrun']
    return {
        'runID': report['runID'], 'mode': report['mode'], 'status': report['status'],
        'stoppedByUser': any(e['kind'] == 'userStopped' for e in events),
        'completedUnits': len(generations), 'audioSeconds': audio_seconds,
        'generationWallSeconds': generation_seconds,
        'generationWallRTF': generation_seconds / audio_seconds if audio_seconds else None,
        'generationIncludesPlaybackBackpressure': report['mode'].endswith('background'),
        'firstChunkSeconds': first,
        'peakPhysicalGiB': report['peakPhysicalBytes'] / 2**30,
        'peakMLXGiB': report['peakMLXBytes'] / 2**30,
        'memoryWarnings': report['warnings'],
        'memoryGuardStops': sum(e['kind'] == 'memoryGuardStopped' for e in events),
        'maxThermalState': max((e['thermalState'] for e in events), default=None),
        'backgroundGPUGranted': any(e['kind'] == 'backgroundGPUGranted' for e in events),
        'backgroundTaskExpired': any(e['kind'] == 'backgroundTaskExpired' for e in events),
        'lockedGeneratedSeconds': sum(e['samples'] / 24000 for e in locked_audio),
        'lockedPlayedSeconds': sum(e['samples'] / 24000 for e in locked_played),
        'totalPlayedSeconds': sum(e['samples'] / 24000 for e in events if e['kind'] == 'audioPlayed'),
        'cachedPlaybackOnly': any(e['kind'] == 'cachedPlaybackOnly' for e in events),
        'unitsStartedWithProtectedDataUnavailable': len(locked_starts),
        'protectedDataUnavailableSpans': spans,
        'protectedDataUnavailableObservationSeconds': sum(s['seconds'] for s in spans),
        'longestProtectedDataUnavailableSpanSeconds': max((s['seconds'] for s in spans), default=0),
        'playbackUnderrunCount': len(underruns),
        'playbackUnderrunSeconds': sum(underruns),
        'maxPlaybackUnderrunSeconds': max(underruns, default=0),
        'caveats': [
            'A partial or failed report is not a completed stress test.',
            'Screen lock needs independent device lock-state corroboration.',
            'AVAudioPlayer callbacks are not acoustic loopback measurements.',
            'A finite continued-processing task does not prove indefinite audiobook playback.',
        ],
    }


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('report', type=Path)
    args = parser.parse_args()
    print(json.dumps(summarize(json.loads(args.report.read_text())), indent=2))
