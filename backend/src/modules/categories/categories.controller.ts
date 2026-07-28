import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Query,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiQuery, ApiTags } from '@nestjs/swagger';
import { CategoryType } from '@prisma/client';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { CategoriesService } from './categories.service';
import {
  CreateCategoryDto,
  ReorderCategoriesDto,
  UpdateCategoryDto,
} from './dto/category.dto';

@ApiTags('categories')
@ApiBearerAuth()
@Controller('categories')
export class CategoriesController {
  constructor(private readonly categories: CategoriesService) {}

  @Get()
  @ApiOperation({ summary: 'List categories' })
  @ApiQuery({ name: 'type', enum: CategoryType, required: false })
  @ApiQuery({ name: 'includeArchived', required: false, type: Boolean })
  list(
    @CurrentUser('userId') userId: string,
    @Query('type') type?: CategoryType,
    @Query('includeArchived') includeArchived?: string,
  ) {
    return this.categories.list(userId, type, includeArchived === 'true');
  }

  @Post()
  @ApiOperation({ summary: 'Create a custom category' })
  create(@CurrentUser('userId') userId: string, @Body() dto: CreateCategoryDto) {
    return this.categories.create(userId, dto);
  }

  @Patch('reorder')
  @ApiOperation({ summary: 'Reorder categories' })
  reorder(@CurrentUser('userId') userId: string, @Body() dto: ReorderCategoriesDto) {
    return this.categories.reorder(userId, dto);
  }

  @Patch(':id')
  @ApiOperation({ summary: 'Update a category' })
  update(
    @CurrentUser('userId') userId: string,
    @Param('id') id: string,
    @Body() dto: UpdateCategoryDto,
  ) {
    return this.categories.update(userId, id, dto);
  }

  @Patch(':id/archive')
  @ApiOperation({ summary: 'Archive a category' })
  archive(@CurrentUser('userId') userId: string, @Param('id') id: string) {
    return this.categories.archive(userId, id, true);
  }

  @Patch(':id/unarchive')
  @ApiOperation({ summary: 'Unarchive a category' })
  unarchive(@CurrentUser('userId') userId: string, @Param('id') id: string) {
    return this.categories.archive(userId, id, false);
  }

  @Get(':id/impact')
  @ApiOperation({
    summary: 'How many records deleting this category would destroy',
    description:
      'Call this before DELETE so the confirmation dialog can state exactly what is lost.',
  })
  impact(@CurrentUser('userId') userId: string, @Param('id') id: string) {
    return this.categories.impact(userId, id);
  }

  @Delete(':id')
  @ApiOperation({
    summary: 'Permanently delete a category and every record filed under it',
    description:
      'Irreversible. Deletes the category plus its expenses, incomes, budgets and ' +
      'recurring transactions. Default categories may be deleted too.',
  })
  remove(@CurrentUser('userId') userId: string, @Param('id') id: string) {
    return this.categories.remove(userId, id);
  }
}
