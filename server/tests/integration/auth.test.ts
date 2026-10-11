import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { createTestApp, type TestApp } from '../helpers/test-app.js';

describe('auth & account', () => {
  let t: TestApp;
  beforeAll(async () => {
    t = await createTestApp();
  });
  afterAll(() => t.close());

  it('signs up, returns tokens and creates default settings', async () => {
    const user = await t.signUp({ email: 'Alex@Example.com' });
    expect(user.email).toBe('Alex@Example.com');
    const me = await user.get('/api/v1/users/me').expect(200);
    expect(me.body.data.email).toBe('alex@example.com'); // stored lower-cased
    const settings = await user.get('/api/v1/settings').expect(200);
    expect(settings.body.data).toMatchObject({
      timezone: 'Asia/Colombo',
      themeMode: 'dark',
      dailyGoal: 4,
    });
  });

  it('rejects a duplicate email with 409 and weak passwords with field errors', async () => {
    await t.signUp({ email: 'dup@example.com' });
    const dup = await t.request
      .post('/api/v1/auth/register')
      .send({ fullName: 'X', email: 'DUP@example.com', password: 'Secret123' })
      .expect(409);
    expect(dup.headers['content-type']).toContain('application/problem+json');
    expect(dup.body.code).toBe('email_taken');

    const weak = await t.request
      .post('/api/v1/auth/register')
      .send({ fullName: 'X', email: 'weak@example.com', password: 'short' })
      .expect(422);
    expect(weak.body.errors[0].path).toBe('password');
  });

  it('logs in and refuses wrong passwords without saying which part was wrong', async () => {
    const user = await t.signUp();
    await t.request
      .post('/api/v1/auth/login')
      .send({ email: user.email, password: 'Secret123' })
      .expect(200);
    const bad = await t.request
      .post('/api/v1/auth/login')
      .send({ email: user.email, password: 'Nope1234' })
      .expect(401);
    const unknown = await t.request
      .post('/api/v1/auth/login')
      .send({ email: 'ghost@example.com', password: 'Nope1234' })
      .expect(401);
    expect(bad.body.detail).toBe(unknown.body.detail);
  });

  it('rotates refresh tokens and revokes the session when an old one is replayed', async () => {
    const user = await t.signUp();
    const first = user.tokens.refreshToken;

    const rotated = await t.request
      .post('/api/v1/auth/refresh')
      .send({ refreshToken: first })
      .expect(200);
    const second: string = rotated.body.data.tokens.refreshToken;
    expect(second).not.toBe(first);

    // Replayed within the grace window: refused, session kept.
    await t.request.post('/api/v1/auth/refresh').send({ refreshToken: first }).expect(401);

    // Replayed later: treated as theft, the whole family is revoked.
    t.clock.advance(60_000);
    const reused = await t.request
      .post('/api/v1/auth/refresh')
      .send({ refreshToken: first })
      .expect(401);
    expect(reused.body.code).toBe('refresh_token_reused');
    await t.request.post('/api/v1/auth/refresh').send({ refreshToken: second }).expect(401);
  });

  it('logout ends the session', async () => {
    const user = await t.signUp();
    await t.request
      .post('/api/v1/auth/logout')
      .send({ refreshToken: user.tokens.refreshToken })
      .expect(204);
    await t.request
      .post('/api/v1/auth/refresh')
      .send({ refreshToken: user.tokens.refreshToken })
      .expect(401);
  });

  it('requires a valid bearer token and rejects expired ones', async () => {
    const user = await t.signUp();
    await t.request.get('/api/v1/users/me').expect(401);
    await t.request.get('/api/v1/users/me').set('Authorization', 'Bearer nonsense').expect(401);
    t.clock.advance(16 * 60_000);
    const expired = await user.get('/api/v1/users/me').expect(401);
    expect(expired.body.code).toBe('token_expired');
  });

  it('updates the name, changes the password and deletes the account', async () => {
    const user = await t.signUp();
    const renamed = await user.patch('/api/v1/users/me', { fullName: '  Sam Lee  ' }).expect(200);
    expect(renamed.body.data.fullName).toBe('Sam Lee');

    await user
      .post('/api/v1/users/me/password', { currentPassword: 'wrong', newPassword: 'Newpass123' })
      .expect(401);
    const changed = await user
      .post('/api/v1/users/me/password', {
        currentPassword: 'Secret123',
        newPassword: 'Newpass123',
      })
      .expect(200);
    expect(changed.body.data.tokens.refreshToken).toBeTruthy();
    // Old sessions are gone.
    await t.request
      .post('/api/v1/auth/refresh')
      .send({ refreshToken: user.tokens.refreshToken })
      .expect(401);
    await t.request
      .post('/api/v1/auth/login')
      .send({ email: user.email, password: 'Newpass123' })
      .expect(200);

    await user.del('/api/v1/users/me', { password: 'Newpass123' }).expect(204);
    await t.request
      .post('/api/v1/auth/login')
      .send({ email: user.email, password: 'Newpass123' })
      .expect(401);
  });

  it('answers unknown routes and bad JSON with problem details', async () => {
    const missing = await t.request.get('/api/v1/nope').expect(404);
    expect(missing.body.code).toBe('route_not_found');
    const bad = await t.request
      .post('/api/v1/auth/login')
      .set('Content-Type', 'application/json')
      .send('{"email":')
      .expect(400);
    expect(bad.body.code).toBe('invalid_json');
  });

  it('serves health checks and the OpenAPI document', async () => {
    await t.request.get('/health/live').expect(200);
    const ready = await t.request.get('/health/ready').expect(200);
    expect(ready.body.database).toBe('up');
    const doc = await t.request.get('/openapi.json').expect(200);
    expect(doc.body.openapi).toBe('3.1.0');
    expect(Object.keys(doc.body.paths)).toContain('/api/v1/sync/push');
  });
});
