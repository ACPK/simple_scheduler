require "rails_helper"
require "sidekiq/testing"
Sidekiq::Testing.fake!

describe SimpleScheduler::SchedulerJob, type: :job do
  # Active Job for testing
  class SimpleSchedulerTestJob < ActiveJob::Base
    def perform(task_name, time)
    end
  end

  # Sidekiq Worker for testing
  class SimpleSchedulerTestWorker
    include Sidekiq::Worker
    def perform(task_name, time)
    end
  end

  describe "successfully queues" do
    subject(:job) { described_class.perform_later }

    it "queues the job" do
      expect { job }.to change(enqueued_jobs, :size).by(1)
    end

    it "is in default queue" do
      expect(described_class.new.queue_name).to eq("default")
    end
  end

  describe "scheduling tasks using an Active Job class" do
    it "queues two future jobs for the single weekly task" do
      expect do
        described_class.perform_now("spec/simple_scheduler/config/active_job.yml")
      end.to change(enqueued_jobs, :size).by(2)
    end
  end

  describe "scheduling tasks using a Sidekiq::Worker class" do
    it "queues two future jobs for the single weekly task" do
      expect do
        described_class.perform_now("spec/simple_scheduler/config/sidekiq_worker.yml")
      end.to change(SimpleSchedulerTestWorker.jobs, :size).by(2)
    end
  end

  describe "scheduling an hourly task" do
    it "queues jobs for at least six hours into the future by default" do
      expect do
        described_class.perform_now("spec/simple_scheduler/config/hourly_task.yml")
      end.to change(enqueued_jobs, :size).by(7)
    end

    it "respects the queue_ahead global option" do
      expect do
        described_class.perform_now("spec/simple_scheduler/config/queue_ahead_global.yml")
      end.to change(enqueued_jobs, :size).by(3)
    end

    it "respects the queue_ahead option per task" do
      expect do
        described_class.perform_now("spec/simple_scheduler/config/queue_ahead_per_task.yml")
      end.to change(enqueued_jobs, :size).by(4)
    end
  end
end
