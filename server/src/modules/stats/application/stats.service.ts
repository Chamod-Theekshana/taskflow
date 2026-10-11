import type { Clock } from '../../../core/utils/clock.js';
import type { SettingsRepository } from '../../settings/domain/settings.js';
import type { TaskRepository } from '../../tasks/domain/task.repository.js';
import { buildReport, type Period, type ProductivityReport } from '../domain/productivity.js';

export class StatsService {
  constructor(
    private readonly tasks: TaskRepository,
    private readonly settings: SettingsRepository,
    private readonly clock: Clock,
  ) {}

  async summary(userId: string, period: Period, timezone?: string): Promise<ProductivityReport> {
    const zone = timezone ?? (await this.settings.get(userId))?.timezone ?? 'UTC';
    const tasks = await this.tasks.listLive(userId);
    return buildReport(tasks, period, this.clock.now(), zone);
  }
}
