import { passwordMeetsRules } from '../../../core/security/password-hasher.js';
import { z } from '../../../core/http/zod.js';
import { timezoneSchema } from '../../settings/application/settings.schemas.js';
import type { User } from '../domain/user.js';

export const PASSWORD_RULES_MESSAGE = 'Use 8+ characters with upper and lower case and a number.';

export const emailSchema = z
  .email('Enter a valid email address.')
  .max(254)
  .openapi({ example: 'alex@example.com' });

export const newPasswordSchema = z
  .string()
  .max(128)
  .refine(passwordMeetsRules, PASSWORD_RULES_MESSAGE)
  .openapi({ example: 'Secret123', description: PASSWORD_RULES_MESSAGE });

export const RegisterSchema = z
  .object({
    fullName: z
      .string()
      .trim()
      .min(1, 'Tell us what to call you.')
      .max(120)
      .openapi({ example: 'Alex Morgan' }),
    email: emailSchema,
    password: newPasswordSchema,
    timezone: timezoneSchema.optional(),
  })
  .openapi('RegisterRequest');

export const LoginSchema = z
  .object({
    email: emailSchema,
    password: z.string().min(1, 'Enter your password.').max(128).openapi({ example: 'Secret123' }),
  })
  .openapi('LoginRequest');

export const RefreshSchema = z
  .object({
    refreshToken: z.string().min(20).max(200),
  })
  .openapi('RefreshRequest');

export const UserSchema = z
  .object({
    id: z.uuid(),
    email: z.string(),
    fullName: z.string(),
    createdAt: z.string().openapi({ format: 'date-time' }),
  })
  .openapi('User');

export const TokensSchema = z
  .object({
    accessToken: z.string(),
    refreshToken: z.string(),
    tokenType: z.literal('Bearer'),
    expiresIn: z
      .number()
      .int()
      .openapi({ description: 'Access token lifetime in seconds.', example: 900 }),
  })
  .openapi('Tokens');

export const SessionSchema = z
  .object({ user: UserSchema, tokens: TokensSchema })
  .openapi('Session');

export type RegisterInput = z.output<typeof RegisterSchema>;
export type LoginInput = z.output<typeof LoginSchema>;
export type TokensDto = z.infer<typeof TokensSchema>;
export type UserDto = z.infer<typeof UserSchema>;

export function toUserDto(user: User): UserDto {
  return {
    id: user.id,
    email: user.email,
    fullName: user.fullName,
    createdAt: user.createdAt.toISOString(),
  };
}
