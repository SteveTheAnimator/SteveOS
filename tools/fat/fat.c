#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

typedef uint8_t bool;
#define true 1
#define false 0

#pragma pack(push, 1)
typedef struct {
    uint8_t  BootJumpInstruction[3];
    uint8_t  OemIdentifier[8];
    uint16_t BytesPerSector;
    uint8_t  SectorsPerCluster;
    uint16_t ReservedSectors;
    uint8_t  FatCount;
    uint16_t DirEntryCount;
    uint16_t TotalSectors;
    uint8_t  MediaDescriptorType;
    uint16_t SectorsPerFat;
    uint16_t SectorsPerTrack;
    uint16_t Heads;
    uint32_t HiddenSectors;
    uint32_t LargeSectorCount;

    uint8_t  DriveNumber;
    uint8_t  _Reserved;
    uint8_t  Signature;
    uint32_t VolumeId;
    uint8_t  VolumeLabel[11];
    uint8_t  SystemId[8];
} BootSector;

typedef struct {
    uint8_t  Name[11];
    uint8_t  Attributes;
    uint8_t  _Reserved;
    uint8_t  CreatedTimeTenths;
    uint16_t CreatedTime;
    uint16_t CreatedDate;
    uint16_t AccessedDate;
    uint16_t FirstClusterHigh;
    uint16_t ModifiedTime;
    uint16_t ModifiedDate;
    uint16_t FirstClusterLow;
    uint32_t Size;
} DirectoryEntry;
#pragma pack(pop)

static BootSector g_BootSector;
static uint8_t* g_Fat = NULL;
static DirectoryEntry* g_RootDirectory = NULL;
static uint32_t g_RootDirectorySectorStart;

bool readBootSector(FILE* disk) {
    return fread(&g_BootSector, sizeof(g_BootSector), 1, disk) == 1;
}

bool readSectors(FILE* disk, uint32_t lba, uint32_t count, void* buffer) {
    if (fseek(disk, (long)lba * g_BootSector.BytesPerSector, SEEK_SET) != 0)
        return false;
    return fread(buffer, g_BootSector.BytesPerSector, count, disk) == count;
}

bool readFat(FILE* disk) {
    size_t fatSize = g_BootSector.SectorsPerFat * g_BootSector.BytesPerSector;
    g_Fat = malloc(fatSize);
    if (!g_Fat) return false;
    return readSectors(disk, g_BootSector.ReservedSectors, g_BootSector.SectorsPerFat, g_Fat);
}

bool readRootDirectory(FILE* disk) {
    g_RootDirectorySectorStart = g_BootSector.ReservedSectors + g_BootSector.SectorsPerFat * g_BootSector.FatCount;

    size_t dirSize = sizeof(DirectoryEntry) * g_BootSector.DirEntryCount;
    size_t sectors = dirSize / g_BootSector.BytesPerSector;
    if (dirSize % g_BootSector.BytesPerSector)
        sectors++;

    g_RootDirectory = malloc(sectors * g_BootSector.BytesPerSector);
    if (!g_RootDirectory) return false;

    return readSectors(disk, g_RootDirectorySectorStart, (uint32_t)sectors, g_RootDirectory);
}

DirectoryEntry* findFile(const char* name) {
    // Format name to 11 chars, space padded, uppercase
    char formattedName[12] = { ' ' };
    size_t len = strlen(name);
    size_t i = 0;

    for (i = 0; i < 11 && i < len; i++) {
        formattedName[i] = toupper((unsigned char)name[i]);
    }
    for (; i < 11; i++) {
        formattedName[i] = ' ';
    }
    formattedName[11] = '\0';

    for (uint32_t i = 0; i < g_BootSector.DirEntryCount; i++) {
        if (memcmp(g_RootDirectory[i].Name, formattedName, 11) == 0)
            return &g_RootDirectory[i];
    }
    return NULL;
}

bool readFile(DirectoryEntry* fileEntry, FILE* disk, uint8_t* outputBuffer) {
    uint16_t cluster = fileEntry->FirstClusterLow;
    uint32_t bytesLeft = fileEntry->Size;
    const uint32_t bytesPerCluster = g_BootSector.SectorsPerCluster * g_BootSector.BytesPerSector;

    while (cluster >= 2 && cluster < 0x0FF8) {
        uint32_t sector = g_RootDirectorySectorStart + 
            (g_BootSector.DirEntryCount * sizeof(DirectoryEntry) + g_BootSector.BytesPerSector - 1) / g_BootSector.BytesPerSector // just root dir size in sectors
            + (cluster - 2) * g_BootSector.SectorsPerCluster;

        if (!readSectors(disk, sector, g_BootSector.SectorsPerCluster, outputBuffer))
            return false;

        size_t toCopy = bytesLeft < bytesPerCluster ? bytesLeft : bytesPerCluster;
        outputBuffer += toCopy;
        bytesLeft -= toCopy;

        // Read next cluster from FAT12
        size_t fatIndex = cluster + (cluster / 2);
        uint16_t nextCluster;
        if (cluster & 1) {
            nextCluster = (*(uint16_t*)(g_Fat + fatIndex - 1)) >> 4;
        } else {
            nextCluster = (*(uint16_t*)(g_Fat + fatIndex)) & 0x0FFF;
        }

        cluster = nextCluster;
    }

    return true;
}

int main(int argc, char** argv) {
    if (argc < 3) {
        fprintf(stderr, "Usage: %s <disk image> <file name>\n", argv[0]);
        return 1;
    }

    FILE* disk = fopen(argv[1], "rb");
    if (!disk) {
        fprintf(stderr, "Failed to open disk image: %s\n", argv[1]);
        return 1;
    }

    if (!readBootSector(disk)) {
        fprintf(stderr, "Failed to read boot sector\n");
        fclose(disk);
        return 1;
    }

    if (!readFat(disk)) {
        fprintf(stderr, "Failed to read FAT\n");
        fclose(disk);
        return 1;
    }

    if (!readRootDirectory(disk)) {
        fprintf(stderr, "Failed to read root directory\n");
        free(g_Fat);
        fclose(disk);
        return 1;
    }

    DirectoryEntry* file = findFile(argv[2]);
    if (!file) {
        fprintf(stderr, "File not found: %s\n", argv[2]);
        free(g_Fat);
        free(g_RootDirectory);
        fclose(disk);
        return 1;
    }

    uint8_t* buffer = malloc(file->Size);
    if (!buffer) {
        fprintf(stderr, "Memory allocation failed\n");
        free(g_Fat);
        free(g_RootDirectory);
        fclose(disk);
        return 1;
    }

    if (!readFile(file, disk, buffer)) {
        fprintf(stderr, "Failed to read file data\n");
        free(buffer);
        free(g_Fat);
        free(g_RootDirectory);
        fclose(disk);
        return 1;
    }

    for (uint32_t i = 0; i < file->Size; i++) {
        if (isprint(buffer[i]))
            fputc(buffer[i], stdout);
        else
            printf("<%02x>", buffer[i]);
    }
    printf("\n");

    free(buffer);
    free(g_Fat);
    free(g_RootDirectory);
    fclose(disk);

    return 0;
}
