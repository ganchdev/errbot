# frozen_string_literal: true

module IssueFrames
  class Component < ApplicationComponent

    prop :frames, default: -> { [] }

    def normalized_frames
      @normalized_frames ||= Array(frames).grep(Hash)
    end

    def frame_title(frame)
      [
        frame_location(frame),
        "in #{frame_function(frame)}",
        "at line #{frame_line_number(frame)}"
      ].join(" ")
    end

    def frame_source_lines(frame)
      pre_context = Array(frame["pre_context"])
      context_line = frame["context_line"]
      post_context = Array(frame["post_context"])
      context_lineno = integer_or_nil(frame["lineno"])
      start_lineno = context_lineno ? context_lineno - pre_context.length : nil

      [
        *pre_context.each_with_index.map do |line, index|
          build_line(start_lineno ? start_lineno + index : nil, line, highlight: false)
        end,
        build_line(context_lineno, context_line, highlight: true),
        *post_context.each_with_index.map do |line, index|
          build_line(context_lineno ? context_lineno + index + 1 : nil, line, highlight: false)
        end
      ]
    end

    def source_line_row_classes(line)
      [
        "flex",
        "items-start",
        "gap-4",
        "px-4",
        "py-1.5",
        (line[:highlight] ? "bg-[rgba(211,211,211,0.3)]" : "bg-transparent")
      ].join(" ")
    end

    def source_line_number_classes(_line)
      "w-12 shrink-0 select-none text-right text-zinc-500"
    end

    def source_line_code_classes(_line)
      "block min-w-0 flex-1 whitespace-pre text-zinc-100 language-ruby"
    end

    private

    def build_line(number, content, highlight:)
      {
        number: number,
        content: content.to_s.chomp,
        highlight: highlight
      }
    end

    def frame_location(frame)
      frame["filename"].presence || frame["abs_path"].presence || "unknown file"
    end

    def frame_function(frame)
      frame["function"].presence || "unknown function"
    end

    def frame_line_number(frame)
      integer_or_nil(frame["lineno"]) || "?"
    end

    def integer_or_nil(value)
      Integer(value)
    rescue ArgumentError, TypeError
      nil
    end

  end
end
