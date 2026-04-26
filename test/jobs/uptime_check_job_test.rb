# frozen_string_literal: true

require "test_helper"

class CheckUptimeJobTest < ActiveJob::TestCase

  setup do
    @project_with_url = projects(:one)
    @project_with_url.update!(url: "https://example.com")
    @project_without_url = projects(:two)
    @project_without_url.update!(url: nil)
  end

  test "checks uptime for all projects with URLs" do
    mock_response = create_mock_response(200)

    Net::HTTP.stub :start, -> (*_args, &block) { block.call(mock_http_for_response(mock_response)) } do
      assert_difference "UptimeCheck.count", 1 do
        assert_no_difference "TelegramMessage.count" do
          CheckUptimeJob.perform_now
        end
      end
    end

    uptime_check = @project_with_url.uptime_checks.last
    assert_equal "up", uptime_check.status
    assert_equal 200, uptime_check.response_code
    assert_not_nil uptime_check.response_time_ms
    assert_not_nil uptime_check.checked_at
  end

  test "marks project as down when response code is 4xx or 5xx" do
    mock_response = create_mock_response(404)

    Net::HTTP.stub :start, -> (*_args, &block) { block.call(mock_http_for_response(mock_response)) } do
      assert_difference "UptimeCheck.count", 1 do
        assert_difference "TelegramMessage.count", 1 do
          assert_enqueued_jobs 1, only: NotifyTelegramJob do
            CheckUptimeJob.perform_now
          end
        end
      end
    end

    uptime_check = @project_with_url.uptime_checks.last
    assert_equal "down", uptime_check.status
    assert_equal 404, uptime_check.response_code
    assert_equal "project_down", TelegramMessage.last.message_type
    assert_equal uptime_check, TelegramMessage.last.source
  end

  test "marks project as down when request fails" do
    Net::HTTP.stub :start, -> (*_args) { raise Net::OpenTimeout } do
      assert_difference "UptimeCheck.count", 1 do
        assert_difference "TelegramMessage.count", 1 do
          assert_enqueued_jobs 1, only: NotifyTelegramJob do
            CheckUptimeJob.perform_now
          end
        end
      end
    end

    uptime_check = @project_with_url.uptime_checks.last
    assert_equal "down", uptime_check.status
    assert_nil uptime_check.response_code
  end

  test "does not enqueue a duplicate alert when a project stays down" do
    @project_with_url.uptime_checks.create!(
      status: "down",
      checked_at: 5.minutes.ago,
      response_code: 503,
      response_time_ms: 100
    )
    mock_response = create_mock_response(503)

    Net::HTTP.stub :start, -> (*_args, &block) { block.call(mock_http_for_response(mock_response)) } do
      assert_difference "UptimeCheck.count", 1 do
        assert_no_difference "TelegramMessage.count" do
          assert_no_enqueued_jobs only: NotifyTelegramJob do
            CheckUptimeJob.perform_now
          end
        end
      end
    end
  end

  test "enqueues a down alert when a project transitions from up to down" do
    @project_with_url.uptime_checks.create!(
      status: "up",
      checked_at: 5.minutes.ago,
      response_code: 200,
      response_time_ms: 90
    )
    mock_response = create_mock_response(500)

    Net::HTTP.stub :start, -> (*_args, &block) { block.call(mock_http_for_response(mock_response)) } do
      assert_difference "UptimeCheck.count", 1 do
        assert_difference "TelegramMessage.count", 1 do
          assert_enqueued_jobs 1, only: NotifyTelegramJob do
            CheckUptimeJob.perform_now
          end
        end
      end
    end
  end

  test "skips projects without URLs" do
    mock_response = create_mock_response(200)

    Net::HTTP.stub :start, -> (*_args, &block) { block.call(mock_http_for_response(mock_response)) } do
      CheckUptimeJob.perform_now
    end

    assert_equal 1, UptimeCheck.count
    assert_equal @project_with_url, UptimeCheck.last.project
  end

  test "records response time in milliseconds" do
    mock_response = create_mock_response(200)

    Net::HTTP.stub :start, -> (*_args, &block) { block.call(mock_http_for_response(mock_response)) } do
      CheckUptimeJob.perform_now
    end

    uptime_check = @project_with_url.uptime_checks.last
    assert uptime_check.response_time_ms >= 0
  end

  private

  def create_mock_response(status_code)
    response = Net::HTTPResponse.new("1.1", status_code.to_s, "OK")
    response.instance_variable_set(:@header, {})
    response
  end

  def mock_http_for_response(response)
    mock = Minitest::Mock.new
    mock.expect(:head, response, ["/"])
    mock
  end

end
