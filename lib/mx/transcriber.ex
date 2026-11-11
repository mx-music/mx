defmodule Mx.Transcriber do
  @moduledoc """
  Transcribes images of single systems of printed music to ABC notation with a vision-language model, which `Mx.ABC` turns into a score.

  The model is rokot-omr-2b from Hugging Face by default, or the Hugging Face id or local folder named in the `MX_TRANSCRIBER_MODEL` environment variable.
  It runs in Python inside this OS process, through Pythonx: the first run installs Python, PyTorch and transformers with uv, and downloads the model into the Hugging Face cache.
  """

  @model "rokotmidi/rokot-omr-2b"
  @width 1400

  @pyproject """
  [project]
  name = "mx-transcriber"
  version = "0.0.0"
  requires-python = "==3.12.*"
  dependencies = ["torch==2.15.0", "torchvision==0.29.2", "transformers==5.22.2", "pillow==13.0.0"]
  """

  @load """
  import torch
  from transformers import AutoModelForImageTextToText, AutoProcessor
  device = "mps" if torch.backends.mps.is_available() else "cuda" if torch.cuda.is_available() else "cpu"
  model = AutoModelForImageTextToText.from_pretrained(name.decode(), dtype=torch.bfloat16).to(device)
  processor = AutoProcessor.from_pretrained(name.decode())
  """

  @transcribe """
  messages = [{"role": "user", "content": [{"type": "image", "image": image.decode()}, {"type": "text", "text": "Transcribe this staff to rokot-ABC."}]}]
  inputs = processor.apply_chat_template(messages, tokenize=True, add_generation_prompt=True, return_dict=True, return_tensors="pt").to(device)
  result = model.generate(**inputs, max_new_tokens=1600, do_sample=False)
  processor.decode(result[0][inputs["input_ids"].shape[1]:], skip_special_tokens=True)
  """

  @doc "The width in pixels to give each system, about 1400 as the model card of rokot-omr-2b asks."
  def width, do: @width

  @doc "The ABC text of each system image, in order, as `{:ok, [abc]}` or `{:error, message}`."
  def transcribe(images) when is_list(images) do
    name = Application.get_env(:mx, :transcriber_model) || @model

    with :ok <- start(),
         {:ok, globals} <- python(fn -> @load |> Pythonx.eval(%{"name" => name}) |> elem(1) end) do
      transcribe_all(images, globals, [])
    end
  end

  defp transcribe_all([], _globals, found), do: {:ok, Enum.reverse(found)}

  defp transcribe_all([image | rest], globals, found) do
    case python(fn -> transcribe_one(image, globals) end) do
      {:ok, abc} -> transcribe_all(rest, globals, [abc | found])
      error -> error
    end
  end

  defp transcribe_one(image, globals) do
    {result, _globals} = Pythonx.eval(@transcribe, Map.put(globals, "image", image))
    Pythonx.decode(result)
  end

  # The interpreter is set up once per OS process.
  defp start do
    {:ok, _started} = Application.ensure_all_started(:pythonx)

    if :persistent_term.get({__MODULE__, :started}, false) do
      :ok
    else
      Pythonx.uv_init(@pyproject)
      :persistent_term.put({__MODULE__, :started}, true)
    end
  end

  defp python(fun) do
    {:ok, fun.()}
  rescue
    error in Pythonx.Error ->
      exception =
        error
        |> Exception.message()
        |> String.split("\n", trim: true)
        |> List.last()
        |> String.trim()

      {:error, "the transcriber failed: #{exception}"}
  end
end
