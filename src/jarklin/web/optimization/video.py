# -*- coding=utf-8 -*-
r"""

"""
import time
import shlex
import logging
import subprocess
import typing as t
import flask
from werkzeug.exceptions import BadRequest as HTTPBadRequest, ServiceUnavailable as HTTPServiceUnavailable
from ...common.executables import ffmpeg_executable


__all__ = ['optimize_video', 'BITRATE_MAP']


logger = logging.getLogger(__name__)


def optimize_video(fp: str):
    def generator(args: t.List[str]):
        logger.info(f"Running: {shlex.join(args)}")
        process = subprocess.Popen(args, stdout=subprocess.PIPE, stderr=subprocess.PIPE, bufsize=-1)
        time.sleep(0.1)  # wait for startup and something in the buffer
        try:
            while process.poll() is None:
                line = process.stdout.read(1024)
                logger.log(logging.NOTSET, f"Sending {len(line)} bytes")
                yield line
        except GeneratorExit:
            process.terminate()
        except Exception as error:
            logging.critical("video optimization failed", exc_info=error)
            raise error
        else:
            logger.info("video optimization completed")
            if process.returncode > 0:
                stderr = process.stderr.read().decode()
                logging.error(f"ffmpeg failed for unknown reason:\n{stderr}")
                # raise subprocess.CalledProcessError(process.returncode, process.args)

    return flask.Response(
        flask.stream_with_context(generator(build_args(fp=fp))),
        mimetype="video/mpeg",
        direct_passthrough=True
    )


def build_args(fp: str) -> t.List[str]:
    resolution = flask.request.args.get("resolution", None)
    video_config: t.Optional[OptimizationInfo] = None
    if resolution is not None:
        logger.info(f"Resizing video... ({resolution})")
        video_config = BITRATE_MAP.get(resolution, None)
        if video_config is None:
            raise HTTPBadRequest(f"Invalid resolution: {resolution!r}")

    video_stream = flask.request.args.get("video", default=None, type=int)
    audio_stream = flask.request.args.get("audio", default=None, type=int)
    subtitle_stream = flask.request.args.get("subtitle", default=None, type=int)

    try:
        ffmpeg = ffmpeg_executable()
    except FileNotFoundError:
        raise HTTPServiceUnavailable("ffmpeg executable not found")

    args = [
        ffmpeg,
        '-hide_banner',
        '-loglevel', "error",
        '-i', str(fp),
    ]

    if video_stream is not None:
        logger.debug(f"Selecting video stream {video_stream}")
        args.extend([
            '-map', f"0:v:{video_stream}",  # select video-stream i
        ])

    if audio_stream is not None:
        logger.debug(f"Selecting audio stream {video_stream}")
        args.extend([
            '-map', f"0:a:{audio_stream}",  # select audio-stream i
        ])

    if subtitle_stream is not None:
        logger.debug(f"Selecting subtitle stream {video_stream}")
        args.extend([
            '-map', f"0:s:{subtitle_stream}",  # select subtitle-stream i
        ])
    else:
        logger.debug(f"Removing subtitles")
        args.extend([
            '-sn',  # skip-subtitle-stream
        ])

    if video_config:
        logger.debug("Applying video resolution")
        args.extend([
            '-vf', fr"scale=if(lt(iw\,ih)\,min({video_config.height}\,iw)\,-2)"
                   fr":if(gte(iw\,ih)\,min({video_config.height}\,ih)\,-2)",
            '-movflags', "faststart",  # web optimized. faster readiness
            '-fpsmax', f"{video_config.max_fps}",
            "-b:v", video_config.video_bitrate,
            "-b:a", video_config.audio_bitrate,
            # "-acodec", "libmp3lame",  # audio-codec
            # "-scodec", "copy",  # copy subtitles
            '-f', "mpegts",
        ])
    else:
        args.extend([
            '-c', "copy",  # copy codec
            '-f', "mpegts",  # specify codec for pipe:stdout
        ])

    args.extend([
        "pipe:stdout",
    ])
    return args


class OptimizationInfo(t.NamedTuple):
    video_bitrate: str
    audio_bitrate: str
    max_fps: int
    height: int


BITRATE_MAP: t.Dict[str, OptimizationInfo] = {
    '240p': OptimizationInfo(video_bitrate="300k", audio_bitrate="32k", max_fps=30, height=240),
    '360p': OptimizationInfo(video_bitrate="500k", audio_bitrate="48k", max_fps=30, height=360),
    '480p': OptimizationInfo(video_bitrate="1000k", audio_bitrate="64k", max_fps=30, height=480),
    '720p': OptimizationInfo(video_bitrate="1500k", audio_bitrate="128k", max_fps=30, height=720),
    '720p60': OptimizationInfo(video_bitrate="2250k", audio_bitrate="128k", max_fps=60, height=720),
    '1080p': OptimizationInfo(video_bitrate="3000k", audio_bitrate="192k", max_fps=30, height=1080),
    '1080p60': OptimizationInfo(video_bitrate="4500k", audio_bitrate="192k", max_fps=60, height=1080),
    '1440p': OptimizationInfo(video_bitrate="6000k", audio_bitrate="320k", max_fps=30, height=1440),
    '1440p60': OptimizationInfo(video_bitrate="9000k", audio_bitrate="320k", max_fps=60, height=1440),
    '2160p': OptimizationInfo(video_bitrate="13000k", audio_bitrate="448k", max_fps=30, height=2160),
    '2160p60': OptimizationInfo(video_bitrate="20000k", audio_bitrate="448k", max_fps=60, height=2160),
}
