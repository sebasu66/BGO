#!/usr/bin/env python3
"""Build a BGO multi-representation asset manifest from a model and turntable media."""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw


def _run(command: list[str]) -> str:
    result = subprocess.run(command, check=True, text=True, capture_output=True)
    return result.stdout


def _probe_frames(ffprobe: str, media: Path) -> tuple[int, int, int]:
    payload = json.loads(
        _run(
            [
                ffprobe,
                "-v",
                "error",
                "-count_frames",
                "-select_streams",
                "v:0",
                "-show_entries",
                "stream=width,height,nb_read_frames",
                "-of",
                "json",
                str(media),
            ]
        )
    )
    stream = payload["streams"][0]
    return int(stream["nb_read_frames"]), int(stream["width"]), int(stream["height"])


def _resource_path(project_root: Path, path: Path) -> str:
    return "res://" + path.resolve().relative_to(project_root.resolve()).as_posix()


def _build_round_avatar(source: Path, output: Path, size: int) -> None:
    with Image.open(source).convert("RGBA") as image:
        crop_size = min(image.width, image.height)
        left = (image.width - crop_size) // 2
        top = (image.height - crop_size) // 2
        avatar = image.crop((left, top, left + crop_size, top + crop_size))
        avatar = avatar.resize((size, size), Image.Resampling.LANCZOS)
        mask = Image.new("L", (size, size), 0)
        ImageDraw.Draw(mask).ellipse((0, 0, size - 1, size - 1), fill=255)
        avatar.putalpha(ImageChops.multiply(avatar.getchannel("A"), mask))
        avatar.save(output)


def _remove_connected_background(frame: Path, threshold: int) -> bool:
    """Remove an opaque, near-uniform backdrop connected to the image edges."""
    with Image.open(frame).convert("RGBA") as image:
        alpha = image.getchannel("A")
        if alpha.getextrema()[0] < 255:
            return False
        transparent = (0, 0, 0, 0)
        corners = (
            (0, 0),
            (image.width - 1, 0),
            (0, image.height - 1),
            (image.width - 1, image.height - 1),
        )
        for corner in corners:
            ImageDraw.floodfill(image, corner, transparent, thresh=threshold)
        alpha_extrema = image.getchannel("A").getextrema()
        if alpha_extrema != (0, 255):
            raise SystemExit(f"background removal did not preserve foreground and transparency: {frame}")
        image.save(frame)
        return True


def _validate_glb(model: Path, label: str) -> None:
    if model.suffix.lower() != ".glb":
        raise SystemExit(f"{label} must be an optimized .glb: {model}")
    if model.stat().st_size > 50 * 1024 * 1024:
        raise SystemExit(f"{label} exceeds the 50 MiB runtime model budget: {model}")
    with model.open("rb") as handle:
        if handle.read(4) != b"glTF":
            raise SystemExit(f"{label} is not a valid binary GLB: {model}")


def _validate_source_model(model: Path) -> None:
    if model.suffix.lower() not in {".fbx", ".blend", ".obj"}:
        raise SystemExit(f"source-model must be an authoring model (.fbx/.blend/.obj): {model}")
    if model.stat().st_size == 0:
        raise SystemExit(f"source-model is empty: {model}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--asset-id", required=True)
    parser.add_argument("--model", type=Path, required=True)
    parser.add_argument("--lod-model", type=Path)
    parser.add_argument("--source-model", type=Path)
    parser.add_argument("--turntable", type=Path, required=True)
    parser.add_argument("--portrait", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--project-root", type=Path, default=Path.cwd())
    parser.add_argument("--front-frame", type=int, default=0)
    parser.add_argument("--expected-frame-count", type=int, default=31)
    parser.add_argument("--avatar-size", type=int, default=512)
    parser.add_argument("--background-threshold", type=int, default=48)
    parser.add_argument("--direction", choices=("clockwise", "counter_clockwise"), default="clockwise")
    parser.add_argument("--model-front-axis", choices=("+z", "-z"), default="-z")
    parser.add_argument("--near-distance", type=float, default=9.0)
    parser.add_argument("--height-cm", type=float)
    parser.add_argument("--base-diameter-cm", type=float)
    parser.add_argument("--world-units-per-cm-fallback", type=float, default=0.24)
    parser.add_argument("--billboard-vertical-offset-cm", type=float, default=0.0)
    parser.add_argument("--ffmpeg", default=shutil.which("ffmpeg") or "ffmpeg")
    parser.add_argument("--ffprobe", default=shutil.which("ffprobe") or "ffprobe")
    args = parser.parse_args()

    project_root = args.project_root.resolve()
    model = args.model.resolve()
    turntable = args.turntable.resolve()
    portrait = args.portrait.resolve()
    output = args.output.resolve()
    if not model.is_file():
        raise SystemExit(f"model not found: {model}")
    if not turntable.is_file():
        raise SystemExit(f"turntable not found: {turntable}")
    if not portrait.is_file():
        raise SystemExit(f"portrait not found: {portrait}")
    _validate_glb(model, "model")
    lod_model = args.lod_model.resolve() if args.lod_model else None
    if lod_model is not None:
        if not lod_model.is_file():
            raise SystemExit(f"lod-model not found: {lod_model}")
        _validate_glb(lod_model, "lod-model")
    source_model = args.source_model.resolve() if args.source_model else None
    if source_model is not None:
        if not source_model.is_file():
            raise SystemExit(f"source-model not found: {source_model}")
        _validate_source_model(source_model)
    output.mkdir(parents=True, exist_ok=True)

    frame_count, source_width, source_height = _probe_frames(args.ffprobe, turntable)
    if frame_count != args.expected_frame_count:
        raise SystemExit(
            f"turntable must contain exactly {args.expected_frame_count} frames; found {frame_count}"
        )
    if not 0 <= args.front_frame < frame_count:
        raise SystemExit("front-frame is outside the media frame range")

    frames_dir = output / "frames"
    frames_dir.mkdir(parents=True, exist_ok=True)
    for stale_frame in frames_dir.glob("frame_*.png"):
        stale_frame.unlink()
    _run(
        [
            args.ffmpeg,
            "-y",
            "-v",
            "error",
            "-i",
            str(turntable),
            "-vsync",
            "0",
            "-start_number",
            "0",
            str(frames_dir / "frame_%03d.png"),
        ]
    )
    frame_files = sorted(frames_dir.glob("frame_*.png"))
    if len(frame_files) != frame_count:
        raise SystemExit(f"expected {frame_count} frames, extracted {len(frame_files)}")
    background_removed = False
    for frame in frame_files:
        background_removed = _remove_connected_background(frame, args.background_threshold) or background_removed

    avatar_path = output / f"{args.asset_id}_avatar.png"
    _build_round_avatar(portrait, avatar_path, args.avatar_size)

    angle_step = 360.0 / frame_count
    frames = []
    direction_sign = 1.0 if args.direction == "clockwise" else -1.0
    for frame_index in range(frame_count):
        relative_index = (frame_index - args.front_frame) % frame_count
        frames.append(
            {
                "frame": frame_index,
                "angle_degrees": round((relative_index * angle_step * direction_sign) % 360.0, 6),
                "path": _resource_path(project_root, frame_files[frame_index]),
                "calibration": {"scale": 1.0, "offset_pixels": [0.0, 0.0]},
            }
        )

    manifest = {
        "schema": "bgo.asset-representations",
        "version": 1,
        "asset_id": args.asset_id,
        "physical_size_cm": {
            "height": args.height_cm,
            "base_diameter": args.base_diameter_cm,
        },
        "world_units_per_cm_fallback": args.world_units_per_cm_fallback,
        "source": {
            "model": _resource_path(project_root, model),
            "turntable": _resource_path(project_root, turntable),
            "turntable_size": [source_width, source_height],
        },
        "selection": {
            "desktop_near_distance": args.near_distance,
            "desktop_near": "desktop_model",
            "desktop_far": "desktop_lod" if lod_model is not None else "billboard",
            "web": "billboard",
            "mobile": "billboard",
            "tactical": "top_down_avatar",
            "fallback": "billboard",
        },
        "client_profiles": {
            "windows_native": {
                "quality": "desktop_high",
                "camera": "free_perspective",
                "near_representation": "desktop_model",
                "far_representation": "desktop_lod" if lod_model is not None else "billboard",
                "tactical_view": "orthographic_top_down",
            },
            "web": {
                "quality": "web_billboard",
                "camera": "fixed_height_pitch_orbit",
                "representation": "billboard",
                "tactical_view": "orthographic_top_down",
            },
            "mobile": {
                "quality": "mobile_billboard",
                "camera": "fixed_height_pitch_orbit",
                "representation": "billboard",
                "tactical_view": "orthographic_top_down",
            },
        },
        "representations": {
            "desktop_model": {
                "type": "model",
                "path": _resource_path(project_root, model),
                "profile": "desktop_high",
            },
            "billboard": {
                "type": "billboard_frames",
                "profile": "web_mobile",
                "frame_count": frame_count,
                "frame_size": [source_width, source_height],
                "front_frame": args.front_frame,
                "direction": args.direction,
                "front_axis": args.model_front_axis,
                "vertical_offset_cm": args.billboard_vertical_offset_cm,
                "transparent_background": (
                    "connected_edge_flood_fill" if background_removed else "source_alpha"
                ),
                "frames": frames,
            },
            "top_down_avatar": {
                "type": "portrait_token",
                "profile": "tactical_2d",
                "path": _resource_path(project_root, avatar_path),
                "shape": "circle",
                "size": [args.avatar_size, args.avatar_size],
            },
        },
    }
    if source_model is not None:
        manifest["source"]["original_model"] = _resource_path(project_root, source_model)
    if lod_model is not None:
        manifest["representations"]["desktop_lod"] = {
            "type": "model",
            "path": _resource_path(project_root, lod_model),
            "profile": "desktop_standard",
        }
    if args.height_cm is None or args.base_diameter_cm is None:
        manifest.pop("physical_size_cm")
    manifest_path = output / "representation.json"
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(manifest_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
