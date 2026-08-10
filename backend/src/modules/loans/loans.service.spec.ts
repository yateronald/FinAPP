import { BadRequestException } from '@nestjs/common';
import { LoanDirection, LoanStatus } from '@prisma/client';
import { LoansService } from './loans.service';

/**
 * The direction rule is the security boundary of the lent-loans feature.
 *
 * A loan's progress is derived entirely from the transactions linked to it, so
 * a client that managed to link an income to a BORROWED loan would make a debt
 * look repaid without a franc moving. `assertPayable` is the only thing
 * standing between the request and that, and it is reached from both the
 * expense and the income endpoint — hence the tests below.
 */
describe('LoansService.assertPayable', () => {
  const loanRow = (over: Record<string, unknown> = {}) => ({
    id: 'loan-1',
    status: LoanStatus.ACTIVE,
    direction: LoanDirection.BORROWED,
    ...over,
  });

  function make(found: unknown) {
    const prisma = {
      loan: { findFirst: jest.fn().mockResolvedValue(found) },
    };
    return {
      service: new LoansService(prisma as never),
      prisma,
    };
  }

  it('accepts an expense against a borrowed loan', async () => {
    const { service } = make(loanRow());
    await expect(
      service.assertPayable('u1', 'loan-1', LoanDirection.BORROWED),
    ).resolves.toBeDefined();
  });

  it('accepts an income against a lent loan', async () => {
    const { service } = make(loanRow({ direction: LoanDirection.LENT }));
    await expect(
      service.assertPayable('u1', 'loan-1', LoanDirection.LENT),
    ).resolves.toBeDefined();
  });

  it('rejects an income claiming to settle a loan the user took out', async () => {
    const { service } = make(loanRow({ direction: LoanDirection.BORROWED }));
    await expect(
      service.assertPayable('u1', 'loan-1', LoanDirection.LENT),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('rejects an expense claiming to settle money the user lent out', async () => {
    const { service } = make(loanRow({ direction: LoanDirection.LENT }));
    await expect(
      service.assertPayable('u1', 'loan-1', LoanDirection.BORROWED),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('defaults to BORROWED so an un-migrated call site cannot silently pass', async () => {
    const { service } = make(loanRow({ direction: LoanDirection.LENT }));
    await expect(service.assertPayable('u1', 'loan-1')).rejects.toBeInstanceOf(
      BadRequestException,
    );
  });

  it('scopes the lookup to the caller — a loan id alone is never enough', async () => {
    const { service, prisma } = make(loanRow());
    await service.assertPayable('u1', 'loan-1', LoanDirection.BORROWED);
    expect(prisma.loan.findFirst).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({ id: 'loan-1', userId: 'u1', deletedAt: null }),
      }),
    );
  });

  it("rejects another user's loan the same way as one that does not exist", async () => {
    const { service } = make(null);
    // Same error either way: the response must not tell a caller whether some
    // other user's loan id is real.
    await expect(
      service.assertPayable('u1', 'someone-elses-loan', LoanDirection.BORROWED),
    ).rejects.toThrow('That loan does not exist.');
  });

  it('rejects an archived loan', async () => {
    const { service } = make(loanRow({ status: LoanStatus.ARCHIVED }));
    await expect(
      service.assertPayable('u1', 'loan-1', LoanDirection.BORROWED),
    ).rejects.toBeInstanceOf(BadRequestException);
  });
});
