# -*- coding=utf-8 -*-
r"""

"""
import logging
import mimetypes
import flask
from .image import optimize_image
from .video import optimize_video


def optimize_file(fp: str):
    mimetype, _ = mimetypes.guess_type(fp)
    if not mimetype:
        return None
    maintype, _, subtype = mimetype.partition("/")
    jit_optimization = flask.current_app.config.get('JIT_OPTIMIZATION', {})
    if not jit_optimization.get(mimetype, False) and not jit_optimization.get(maintype, False):
        return None

    if maintype == "image":
        logging.debug("Attempt to optimize image")
        return optimize_image(fp)
    if maintype == "video":
        logging.debug("Attempt to optimize video")
        return optimize_video(fp)
