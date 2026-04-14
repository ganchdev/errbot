# frozen_string_literal: true

# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin "highlight.js/lib/core", to: "https://cdn.jsdelivr.net/gh/highlightjs/cdn-release@11.11.1/build/es/core.min.js"
pin "highlight.js/lib/languages/ruby", to: "https://cdn.jsdelivr.net/gh/highlightjs/cdn-release@11.11.1/build/es/languages/ruby.min.js"
pin_all_from "app/javascript/controllers", under: "controllers"
pin_all_from "app/components", under: "components", to: ""
