#include <dirent.h>
#include <fcntl.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdnoreturn.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>
#define TAILLE_BLOC 4096
#define CHEMIN_MAX 512

#define CHK(op)            \
    do {                   \
        if ((op) == -1)    \
            raler(1, #op); \
    } while (0)

noreturn void raler(int syserr, const char *msg, ...) {
    va_list ap;

    va_start(ap, msg);
    vfprintf(stderr, msg, ap);
    fprintf(stderr, "\n");
    va_end(ap);

    if (syserr == 1)
        perror("");

    exit(EXIT_FAILURE);
}

typedef struct fichier {
    char name[CHEMIN_MAX];
    off_t size;
} FICHIER;

// Fonction pour le tri rapide fait par qsort
// elle va ranger par ordre croissant de taille de fichier le tableau de
// structure
int compare(const void *a, const void *b) {
    FICHIER *f1 = (FICHIER *)a;
    FICHIER *f2 = (FICHIER *)b;
    return (f1->size - f2->size);
}

// compare les permissions des 3  groupes de 3 bits (rwx) entre deux fichiers
// r pour read, w pour write, x pour execute
// les 3 groupe sont (propriétaire, groupe, autres)
// retourne 0 si les permissions sont identiques, 1 sinon

int compare_permission(char *file1, char *file2) {
    struct stat st1, st2;
    int ret = 0;
    CHK(lstat(file1, &st1));
    CHK(lstat(file2, &st2));

    // j'utilise le masque 0777 pour ne garder que les 3 groupes de 3 bits

    if ((st1.st_mode & 0777) != (st2.st_mode & 0777)) {
        ret = 1;
    }

    return ret;
}

// Fonction pour trier les fichiers par taille et mettre comme premier argument
// le tableau de structure et comme deuxieme argument la taille du tableau

void tri_taille(void *tab, int taille) {
    qsort(tab, taille, sizeof(struct fichier), compare);
}

// Fonction simple pour comparer deux fichiers bits à bits

int compare_files(char *file1, char *file2) {
    int desc1, desc2;
    CHK(desc1 = open(file1, O_RDONLY));
    CHK(desc2 = open(file2, O_RDONLY));
    struct stat statbuf1, statbuf2;
    CHK(fstat(desc1, &statbuf1));
    CHK(fstat(desc2, &statbuf2));
    char buffer1[TAILLE_BLOC];
    char buffer2[TAILLE_BLOC];

    if (statbuf1.st_size != statbuf2.st_size) {
        return 1;
    }

    while (read(desc1, buffer1, TAILLE_BLOC) > 0 &&
           read(desc2, buffer2, TAILLE_BLOC) > 0) {
        for (int i = 0; i < TAILLE_BLOC; i++) {
            if (buffer1[i] != buffer2[i]) {
                return 1;
            }
        }
    }
    close(desc1);
    close(desc2);
    return 0;
}

int verifier_repertoire(const char *chemin) {
    struct stat statbuf;
    int ret = 0;
    if (lstat(chemin, &statbuf) == -1) {

        raler(1, "erreur stat");
    }
    if (S_ISDIR(statbuf.st_mode)) {
        ret = 1;
    }

    return ret;
}

void analyse_repertoire(const char *chemin, struct fichier *files,
                        int *file_size_index) {
    DIR *dir;

    dir = opendir(chemin);

    if (dir == NULL) {
        raler(1, "erreur ouverture repertoire");
    }

    struct dirent *entry;

    struct stat statbuf;

    if (verifier_repertoire(chemin) == 0) {
        raler(1, "readdir");
    }
    while ((entry = readdir(dir)) != NULL) {
        char chemin_fichier[CHEMIN_MAX];
        snprintf(chemin_fichier, CHEMIN_MAX + 1, "%s/%s", chemin,
                 entry->d_name);

        if (lstat(chemin_fichier, &statbuf) == -1) {
            raler(1, "erreur stat");
        }
        if (S_ISREG(statbuf.st_mode)) {
            if (*file_size_index > 128) {
                files = realloc(files,
                                sizeof(struct fichier) * ((*file_size_index)));
                if (files == NULL) {
                    raler(1, "erreur realloc");
                }
            }
            files[*file_size_index].size = statbuf.st_size;
            strcpy(files[*file_size_index].name, chemin_fichier);
            (*file_size_index)++;
        }

        else if (S_ISDIR(statbuf.st_mode) && strcmp(entry->d_name, ".") != 0 &&
                 strcmp(entry->d_name, "..") != 0) {
            analyse_repertoire(chemin_fichier, files, file_size_index);
        }
    }
    CHK(closedir(dir));
}

int main(int argc, char *argv[]) {

    if (argc != 2) {
        raler(1, "usage : doublons <repertoire>");
    }

    struct fichier *files;
    files = malloc(sizeof(struct fichier) * 128);
    if (files == NULL) {
        raler(1, "erreur malloc");
    }
    int file_size_index = 0;
    analyse_repertoire(argv[1], files, &file_size_index);

    tri_taille(files, file_size_index);

    int *processed_files = calloc(file_size_index, sizeof(int));
    if (processed_files == NULL) {
        raler(1, "erreur calloc");
    }
    for (int i = 0; i < file_size_index; i++) {
        if (processed_files[i] != 1) {

            int same_size = 1;
            int same_permission = 1;
            int j = i + 1;
            processed_files[i] = 1;
            while (j < file_size_index) {
                if (files[j].size == files[i].size &&
                    compare_files(files[i].name, files[j].name) == 0) {
                    if (same_size == 1)
                        printf("%s ", files[i].name);

                    if (!processed_files[j]) {
                        same_size++;
                        processed_files[j] = 1;
                        printf("%s ", files[j].name);
                        if (compare_permission(files[i].name, files[j].name) ==
                            0) {
                            same_permission++;
                        }
                    }
                }
                j++;
            }
            if (same_size > 1) {
                if (same_permission == same_size) {
                    printf("=\n");
                } else {
                    printf("*\n");
                }
            }
        }
    }
    free(processed_files);
    free(files);
    exit(0);
}

//je passe tout les tests sauf le 5.4 et le 5.6