import {
  Controller,
  Post,
  UseGuards,
  UseInterceptors,
  UploadedFile,
  BadRequestException,
  HttpException,
  HttpStatus,
} from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { FileInterceptor } from '@nestjs/platform-express';
import { diskStorage } from 'multer';
import { extname } from 'path';
import { randomUUID } from 'crypto';
import { ApprovalGuard } from '../../common/guards/approval.guard';

const MAX_FILE_SIZE = 20 * 1024 * 1024;
const ALLOWED_MIME = /^(image\/(jpeg|png|gif|webp|heic|heif)|video\/(mp4|quicktime|webm))$/i;

@Controller('api/uploads')
@UseGuards(AuthGuard('jwt'), ApprovalGuard)
export class UploadsController {
  @Post()
  @UseInterceptors(
    FileInterceptor('file', {
      storage: diskStorage({
        destination: '/app/uploads',
        filename: (_req, file, cb) => {
          const ext = extname(file.originalname).toLowerCase().slice(0, 8);
          cb(null, `${randomUUID()}${ext}`);
        },
      }),
      limits: { fileSize: MAX_FILE_SIZE },
      fileFilter: (_req, file, cb) => {
        if (!ALLOWED_MIME.test(file.mimetype)) {
          cb(new BadRequestException(`不支持的文件类型：${file.mimetype}`), false);
          return;
        }
        cb(null, true);
      },
    }),
  )
  async upload(@UploadedFile() file: Express.Multer.File) {
    if (!file) {
      throw new HttpException('未收到文件', HttpStatus.BAD_REQUEST);
    }
    return { url: `/api/uploads/${file.filename}` };
  }
}
