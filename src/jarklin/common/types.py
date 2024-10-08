# -*- coding=utf-8 -*-
r"""

"""
import typing as _t
from os import PathLike as _PathLike


PathSource: _t.TypeAlias = _t.Union[str, _PathLike]


# -------------------------------------------------------------------------------------------------------------------- #


class ProblemEntry(_t.TypedDict):
    file: str
    type: str
    description: str
    traceback: str


# -------------------------------------------------------------------------------------------------------------------- #


class MediaEntry(_t.TypedDict):
    path: str
    name: str
    ext: str
    creation_time: float
    modification_time: float
    meta: _t.Union['GalleryMeta', 'VideoMeta']


# -------------------------------------------------------------------------------------------------------------------- #


class GalleryMeta(_t.TypedDict):
    type: _t.Literal['gallery']
    n_previews: int
    images: _t.List['GalleryImageMeta']


class GalleryImageMeta(_t.TypedDict):
    filename: str
    mimetype: str
    ext: str
    width: int
    height: int
    filesize: int
    is_animated: bool


# -------------------------------------------------------------------------------------------------------------------- #


class VideoMeta(_t.TypedDict):
    type: _t.Literal['video']
    filename: str
    mimetype: str
    width: int
    height: int
    duration: float
    filesize: int
    n_previews: int
    video_streams: _t.List['VideoStreamMeta']
    audio_streams: _t.List['AudioStreamMeta']
    subtitles: _t.List['SubtitleStreamMeta']
    chapters: _t.List['ChapterMeta']


class VideoStreamMeta(_t.TypedDict):
    is_default: bool
    width: int
    height: int
    duration: float
    avg_fps: float


class AudioStreamMeta(_t.TypedDict):
    is_default: bool
    language: str


class SubtitleStreamMeta(_t.TypedDict):
    is_default: bool
    language: str


class ChapterMeta(_t.TypedDict):
    id: int
    # start: int
    start_time: float
    # end: int
    end_time: float
    title: str
