import { AiChatService } from './ai-chat.service';

/**
 * Security unit tests for the read-only SQL guard. These do NOT rely on the LLM
 * behaving — they prove the code itself rejects anything unsafe.
 */
describe('AiChatService.validateReadQuery (security guard)', () => {
  const service = new AiChatService(null as any, null as any);
  const validate = (sql: string) => (service as any).validateReadQuery(sql);

  it('accepts a legitimate read-only query over allowed views', () => {
    const r = validate(
      'SELECT category, SUM(amount) AS total FROM my_expenses GROUP BY category ORDER BY total DESC',
    );
    expect(r.ok).toBe(true);
  });

  it('accepts joins between allowed views', () => {
    const r = validate(
      'SELECT e.category, e.amount FROM my_expenses e JOIN my_budgets b ON b.category = e.category',
    );
    expect(r.ok).toBe(true);
  });

  it('accepts the model’s own CTEs referencing allowed views', () => {
    const r = validate(
      'WITH spend AS (SELECT category, SUM(amount) total FROM my_expenses GROUP BY category) ' +
        'SELECT s.category, s.total, b.amount FROM spend s LEFT JOIN my_budgets b ON b.category = s.category',
    );
    expect(r.ok).toBe(true);
  });

  it('rejects recursive CTEs', () => {
    const r = validate('WITH RECURSIVE x AS (SELECT 1) SELECT * FROM x');
    expect(r.ok).toBe(false);
  });

  it('rejects a CTE that reads a forbidden base table', () => {
    const r = validate('WITH x AS (SELECT email FROM users) SELECT * FROM x');
    expect(r.ok).toBe(false);
  });

  const rejected: [string, string][] = [
    ['non-select', 'WITH x AS (SELECT 1) DELETE FROM my_expenses'],
    ['delete', 'SELECT * FROM my_expenses; DELETE FROM expenses'],
    ['update inline', "UPDATE my_expenses SET amount = 0"],
    ['insert', "INSERT INTO expenses VALUES (1)"],
    ['drop', 'SELECT 1; DROP TABLE users'],
    ['users table', 'SELECT email, password_hash FROM users'],
    ['refresh tokens', 'SELECT token_hash FROM refresh_tokens'],
    ['audit logs', 'SELECT * FROM audit_logs'],
    ['base income table', 'SELECT * FROM income'],
    ['base expenses table', 'SELECT * FROM expenses'],
    ['information_schema', 'SELECT table_name FROM information_schema.tables'],
    ['pg_catalog', 'SELECT * FROM pg_catalog.pg_user'],
    ['multi statement', 'SELECT 1; SELECT 2'],
    ['comment hiding', 'SELECT * FROM my_expenses -- ; DROP TABLE users'],
    ['sensitive column', 'SELECT password FROM my_categories'],
    ['unknown table', 'SELECT * FROM secret_table'],
    ['copy exfil', "SELECT 1 UNION SELECT lo_import('/etc/passwd')"],
    ['pg_sleep dos', 'SELECT pg_sleep(100)'],
  ];

  it.each(rejected)('rejects: %s', (_label, sql) => {
    const r = validate(sql);
    expect(r.ok).toBe(false);
  });
});
