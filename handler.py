"""Runpod serverless handler: generate an image with mflux.

Job input:
    prompt    (str, required)
    model     (str, default: $MFLUX_MODEL or "z-image-turbo")
    seed      (int, optional)
    steps     (int, optional)
    width     (int, optional)
    height    (int, optional)
    guidance  (float, optional)
    quantize  (int, optional: 3, 4, 5, 6 or 8)

Job output:
    {"image_base64": "<PNG>", "seed": ..., "model": ..., "seconds": ...}

The handler runs the `mflux-generate` CLI, so the model loads again for each job.
"""

import base64
import os
import subprocess
import tempfile
import time

import runpod

DEFAULT_MODEL = os.environ.get("MFLUX_MODEL", "z-image-turbo")

# Job input key -> (CLI flag, type)
OPTIONS = {
    "seed": ("--seed", int),
    "steps": ("--steps", int),
    "width": ("--width", int),
    "height": ("--height", int),
    "guidance": ("--guidance", float),
    "quantize": ("--quantize", int),
}


def build_command(job_input: dict, output: str) -> list[str]:
    prompt = job_input.get("prompt")
    if not isinstance(prompt, str) or not prompt.strip():
        raise ValueError("input.prompt must be a non-empty string")
    model = str(job_input.get("model") or DEFAULT_MODEL)

    cmd = ["mflux-generate", "--model", model, "--prompt", prompt, "--output", output]
    for key, (flag, cast) in OPTIONS.items():
        if job_input.get(key) is not None:
            cmd += [flag, str(cast(job_input[key]))]
    return cmd


def handler(job):
    job_input = job["input"] or {}
    with tempfile.TemporaryDirectory() as tmp:
        output = os.path.join(tmp, "image.png")
        try:
            cmd = build_command(job_input, output)
        except (TypeError, ValueError) as exc:
            return {"error": str(exc)}

        start = time.time()
        result = subprocess.run(cmd, check=False, capture_output=True, text=True)
        if result.returncode != 0 or not os.path.exists(output):
            return {"error": "mflux-generate failed", "stderr": result.stderr[-4000:]}

        with open(output, "rb") as fh:
            image = base64.b64encode(fh.read()).decode("ascii")

    return {
        "image_base64": image,
        "model": cmd[cmd.index("--model") + 1],
        "seed": job_input.get("seed"),
        "seconds": round(time.time() - start, 1),
    }


if __name__ == "__main__":
    runpod.serverless.start({"handler": handler})
