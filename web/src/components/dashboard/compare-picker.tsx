'use client';

import { GitCompareArrows } from 'lucide-react';
import { useTranslations } from 'next-intl';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import { RangePicker } from '@/components/layout/range-picker';
import { precedingSelection } from '@/lib/period';
import { usePeriodStore, type CompareMode } from '@/store/period';

export function ComparePicker() {
  const t = useTranslations('dashboard');
  const range = usePeriodStore((s) => s.range);
  const compareMode = usePeriodStore((s) => s.compareMode);
  const compareRange = usePeriodStore((s) => s.compareRange);
  const setCompareMode = usePeriodStore((s) => s.setCompareMode);
  const setCompareRange = usePeriodStore((s) => s.setCompareRange);

  return (
    <div className="flex flex-wrap items-center justify-end gap-2">
      <span className="flex items-center gap-1.5 text-sm text-muted-foreground">
        <GitCompareArrows className="h-4 w-4" />
        {t('comparedTo')}
      </span>
      <Select value={compareMode} onValueChange={(v) => setCompareMode(v as CompareMode)}>
        <SelectTrigger className="h-10 w-[210px]">
          <SelectValue />
        </SelectTrigger>
        <SelectContent>
          <SelectItem value="auto">{t('compareAuto')}</SelectItem>
          <SelectItem value="custom">{t('compareCustom')}</SelectItem>
          <SelectItem value="none">{t('compareNone')}</SelectItem>
        </SelectContent>
      </Select>
      {compareMode === 'custom' && (
        <RangePicker
          value={compareRange ?? precedingSelection(range)}
          onChange={setCompareRange}
          align="end"
          className="w-52"
        />
      )}
    </div>
  );
}
