import type { Logger } from '../logger.js';

export interface Job {
  name: string;
  intervalMs: number;
  run(): Promise<unknown>;
}

/**
 * Runs background jobs on fixed intervals.
 *
 * - A job never overlaps with itself: the next run is scheduled only after
 *   the current one finished.
 * - A failing run is logged and retried on the next tick.
 * - `stop()` waits for runs in flight, so shutdown never cuts a job in half.
 *
 * Jobs claim their rows with `FOR UPDATE SKIP LOCKED`, so several instances
 * can run the scheduler at the same time without sending anything twice.
 */
export class JobScheduler {
  private readonly jobs: Job[] = [];
  private readonly timers = new Map<string, NodeJS.Timeout>();
  private readonly running = new Map<string, Promise<void>>();
  private stopped = true;

  constructor(private readonly logger: Logger) {}

  register(job: Job): this {
    this.jobs.push(job);
    return this;
  }

  start(): void {
    if (!this.stopped) return;
    this.stopped = false;
    for (const job of this.jobs) {
      // Spread the first runs out a little so instances don't all fire together.
      this.schedule(job, Math.floor(Math.random() * Math.min(job.intervalMs, 5_000)));
    }
    this.logger.info({ jobs: this.jobs.map((j) => j.name) }, 'Job scheduler started');
  }

  /** Runs one job right away (tests, admin tools). */
  async runNow(name: string): Promise<void> {
    const job = this.jobs.find((j) => j.name === name);
    if (!job) throw new Error(`Unknown job ${name}`);
    await this.execute(job);
  }

  async stop(): Promise<void> {
    this.stopped = true;
    for (const timer of this.timers.values()) clearTimeout(timer);
    this.timers.clear();
    await Promise.allSettled(this.running.values());
    this.logger.info('Job scheduler stopped');
  }

  private schedule(job: Job, delay: number): void {
    if (this.stopped) return;
    const timer = setTimeout(() => {
      void this.execute(job).finally(() => this.schedule(job, job.intervalMs));
    }, delay);
    timer.unref();
    this.timers.set(job.name, timer);
  }

  private async execute(job: Job): Promise<void> {
    const inFlight = this.running.get(job.name);
    if (inFlight) return inFlight;

    const started = Date.now();
    const run = (async () => {
      try {
        const result = await job.run();
        this.logger.debug({ job: job.name, ms: Date.now() - started, result }, 'Job finished');
      } catch (error) {
        this.logger.error({ err: error, job: job.name }, 'Job failed');
      } finally {
        this.running.delete(job.name);
      }
    })();
    this.running.set(job.name, run);
    return run;
  }
}
