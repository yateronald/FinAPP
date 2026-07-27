'use client';

import { Search, X } from 'lucide-react';
import { useTranslations } from 'next-intl';
import { Input } from '@/components/ui/input';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import { Button } from '@/components/ui/button';
import type { Category } from '@/lib/types';

export interface FilterState {
  search: string;
  categoryId: string;
  from: string;
  to: string;
}

const ALL = '__all__';

export function FilterBar({
  filters,
  onChange,
  categories,
}: {
  filters: FilterState;
  onChange: (next: FilterState) => void;
  categories: Category[];
}) {
  const tc = useTranslations('common');
  const set = (patch: Partial<FilterState>) => onChange({ ...filters, ...patch });
  const active = filters.search || filters.categoryId || filters.from || filters.to;

  return (
    <div className="flex flex-wrap items-center gap-2">
      <div className="relative min-w-[180px] flex-1">
        <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
        <Input
          value={filters.search}
          onChange={(e) => set({ search: e.target.value })}
          placeholder={tc('search')}
          className="pl-9"
        />
      </div>

      <Select
        value={filters.categoryId || ALL}
        onValueChange={(v) => set({ categoryId: v === ALL ? '' : v })}
      >
        <SelectTrigger className="w-[170px]">
          <SelectValue placeholder={tc('category')} />
        </SelectTrigger>
        <SelectContent>
          <SelectItem value={ALL}>{tc('category')}</SelectItem>
          {categories.map((c) => (
            <SelectItem key={c.id} value={c.id}>
              {c.name}
            </SelectItem>
          ))}
        </SelectContent>
      </Select>

      <Input
        type="date"
        value={filters.from}
        onChange={(e) => set({ from: e.target.value })}
        className="w-[150px]"
      />
      <Input
        type="date"
        value={filters.to}
        onChange={(e) => set({ to: e.target.value })}
        className="w-[150px]"
      />

      {active && (
        <Button
          variant="ghost"
          size="icon"
          onClick={() => onChange({ search: '', categoryId: '', from: '', to: '' })}
          aria-label="Clear filters"
        >
          <X className="h-4 w-4" />
        </Button>
      )}
    </div>
  );
}
