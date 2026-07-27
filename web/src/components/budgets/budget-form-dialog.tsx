'use client';

import { useEffect, useState } from 'react';
import { Loader2 } from 'lucide-react';
import { useTranslations } from 'next-intl';
import { toast } from 'sonner';
import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import { useCategories } from '@/hooks/use-categories';

export function BudgetFormDialog({
  open,
  onOpenChange,
  presetCategoryId,
  presetAmount,
  lockCategory,
  onSubmit,
  saving,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  presetCategoryId?: string;
  presetAmount?: number;
  lockCategory?: boolean;
  onSubmit: (values: { categoryId: string; amount: number }) => void;
  saving?: boolean;
}) {
  const t = useTranslations('budgets');
  const tc = useTranslations('common');
  const { data: categories } = useCategories('EXPENSE');

  const [categoryId, setCategoryId] = useState('');
  const [amount, setAmount] = useState('');

  useEffect(() => {
    if (open) {
      setCategoryId(presetCategoryId ?? '');
      setAmount(presetAmount != null ? String(presetAmount) : '');
    }
  }, [open, presetCategoryId, presetAmount]);

  const submit = () => {
    const num = Number(amount);
    if (!categoryId || !Number.isFinite(num) || num < 0) {
      toast.error(tc('save'));
      return;
    }
    onSubmit({ categoryId, amount: num });
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-md">
        <DialogHeader>
          <DialogTitle>{presetCategoryId ? t('edit') : t('add')}</DialogTitle>
        </DialogHeader>

        <div className="space-y-4">
          <div className="space-y-2">
            <Label>{t('selectCategory')}</Label>
            <Select value={categoryId} onValueChange={setCategoryId} disabled={lockCategory}>
              <SelectTrigger>
                <SelectValue placeholder={t('selectCategory')} />
              </SelectTrigger>
              <SelectContent>
                {(categories ?? []).map((c) => (
                  <SelectItem key={c.id} value={c.id}>
                    {c.name}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>

          <div className="space-y-2">
            <Label htmlFor="budget-amount">{t('amountLabel')}</Label>
            <Input
              id="budget-amount"
              type="number"
              min="0"
              step="1"
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              placeholder="0"
            />
          </div>
        </div>

        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)}>
            {tc('cancel')}
          </Button>
          <Button onClick={submit} disabled={saving}>
            {saving && <Loader2 className="h-4 w-4 animate-spin" />}
            {tc('save')}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
