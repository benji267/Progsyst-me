#!/bin/sh

PROG=${PROG:=./doublons}		# chemin de l'exécutable

TMP=${TMP:=/tmp/test}			# chemin des logs de test

#
# Script Shell de test de l'exercice 1
# Utilisation : sh ./test.sh
#
# Si tout se passe bien, le script doit afficher "Tests ok" à la fin
# Dans le cas contraire, le nom du test échoué s'affiche.
# Les fichiers sont laissés dans /tmp/test*, vous pouvez les examiner
# Pour avoir plus de détails sur l'exécution du script, vous pouvez
# utiliser :
#	sh -x ./test.sh
# Toutes les commandes exécutées par le script sont alors affichées.
#

set -u					# erreur si accès variable non définie

# il ne faudrait jamais appeler cette fonction
# argument : message d'erreur
fail ()
{
    local msg="$1"

    echo FAIL				# aie aie aie...
    echo "Échec du test '$msg'."
    exit 1
}

est_vide ()
{
    local fichier="$1"
    test $(wc -l < "$fichier") = 0
}

# Vérifie que le message d'erreur est envoyé sur la sortie d'erreur
# et non sur la sortie standard
# $1 = nom du fichier de log (sans .err ou .out)
verifier_stderr ()
{
    [ $# != 1 ] && fail "ERREUR SYNTAXE verifier_stderr"
    local base="$1"
    est_vide $base.err \
	&& fail "Le message d'erreur devrait être sur la sortie d'erreur"
    est_vide $base.out \
	|| fail "Rien ne devrait être affiché sur la sortie standard"
}

# Vérifie que le message d'erreur indique la bonne syntaxe
# $1 = nom du fichier de log d'erreur
verifier_usage ()
{
    [ $# != 1 ] && fail "ERREUR SYNTAXE verifier_usage"
    local err="$1"
    grep -q "usage *: doublons *<repertoire>" $err \
	|| fail "Message d'erreur devrait indiquer 'usage:...'"
}

# Compare la sortie du programme avec les doublons attendus
# $1 = fichier résultat
# $2 = attendu
comparer_doublons ()
{
    [ $# != 2 ] && fail "ERREUR SYNTAXE comparer_doublons"
    local out="$1" attendu="$2"
    local nlout nlatt

    # Première partie du test : le nombre de lignes affichées
    # doit correspondre au nombre de lignes attendues
    nlout=$(wc -l < "$out")
    nlatt=$(echo -n "$attendu" | wc -l)
    test $nlout = $nlatt \
	|| fail "Nb doublons trouvés ($nlout) != nb attendus ($nlatt)"

    # La deuxième partie du test est vraiment très primitive :
    # on vérifie juste que tous les fichiers trouvés sont bien
    # identiques aux fichiers attendus (sans vérifier les classes
    # d'équivalence).
    # Si on voulait vérifier exactement, il faudrait vérifier
    # les lignes deux à deux, et à l'intérieur
    tr ' ' '\n' < $out | sort > $TMP.out2
    echo -n "$attendu" | tr ' ' '\n' | sort > $TMP.att2
    diff $TMP.att2 $TMP.out2 > $TMP.diff || fail "doublons non identiques"
}

# Génère des fichiers au contenu aléatoire
# $1 = répertoire
generer_fichiers ()
{
    [ $# != 1 ] && fail "ERREUR SYNTAXE generer_fichiers"
    local rep="$1"
    local i j
    for i in a b c
    do
	for j in 1 5 11
	do
	    # générer des fichiers aléatoires {a,b,c}.{1,5,11} avec
	    # des tailles différentes
	    # 49999 est premier
	    dd if=/dev/urandom bs=49999 count=$j of=$rep/$i.$j 2> /dev/null
	done
    done
}

# Création d'une arborescence simple avec des fichiers aléatoires
# $1 = base
arbo_simple ()
{
    [ $# != 1 ] && fail "ERREUR SYNTAXE arbo_simple"
    local dir="$1"

    rm -rf $dir
    mkdir $dir
    generer_fichiers $dir
}

# Création d'une arborescence complexe avec des fichiers aléatoires
# $1 = base
arbo_complexe ()
{
    [ $# != 1 ] && fail "ERREUR SYNTAXE arbo_complexe"
    local dir="$1"
    local base i j

    rm -rf $dir
    mkdir $dir
    for i in x y z
    do
	base=$dir/$i
	mkdir $base
	for j in t u v
	do
	    base=$base/$j
	    mkdir $base
	    generer_fichiers $base
	done
    done
}

# Génère le code de fausses primitives qui renvoient systématiquement
# des erreurs
# Note : on ne peut pas tester toutes les primitives

faux_read ()
{
    cat <<EOF
#include <unistd.h>
#include <errno.h>
ssize_t read(int fd, void *buf, size_t count) { errno = ELIBBAD ; return -1 ; }
EOF
}

faux_readdir ()
{
    cat <<EOF
#include <dirent.h>
#include <errno.h>
struct dirent *readdir(DIR *dirp) { errno = ELIBBAD ; return 0 ; }
EOF
}

faux_closedir ()
{
    cat <<EOF
#include <dirent.h>
#include <errno.h>
int closedir(DIR *dirp) { errno = ELIBBAD ; return -1 ; }
EOF
}

# Lance le programme avec une fausse primitive qui renvoie systématiquement -1
# $1 = primitive qui doit renvoyer -1
# $2 et suivant : le programme et ses arguments
lancer_faux ()
{
    [ $# -le 2 ] && fail "ERREUR SYNTAXE lancer_faux"
    local ps=$1

    rm -f $TMP.so
    shift
    faux_$ps | gcc -shared -fPIC -o $TMP.so -x c -
    LD_PRELOAD=$TMP.so $@
}

# Le nettoyage façon karscher : il ne reste plus une trace après...
nettoyer ()
{
    chmod -R +rx $TMP.d* 2> /dev/null
    rm -rf $TMP.*
}

##############################################################################
# Tests d'erreur sur les arguments

nettoyer

echo -n "Test 1.1 - pas assez d'arguments.................................... "
$PROG      > $TMP.out 2> $TMP.err	&& fail "pas d'arg"
verifier_stderr $TMP
verifier_usage $TMP.err
echo OK

echo -n "Test 1.2 - trop d'arguments......................................... "
$PROG a b  > $TMP.out 2> $TMP.err	&& fail "2 args"
verifier_stderr $TMP
verifier_usage $TMP.err
echo OK

echo -n "Test 1.3 - répertoire inexistant.................................... "
rm -f $TMP.nonexistant
$PROG $TMP.nonexistant > $TMP.out 2> $TMP.err && fail "répertoire inexistant"
verifier_stderr $TMP
echo OK

echo -n "Test 1.4 - argument pas un répertoire............................... "
touch $TMP.freg
$PROG $TMP.freg > $TMP.out 2> $TMP.err	&& fail "argument non répertoire"
verifier_stderr $TMP
echo OK

##############################################################################
# Tests basiques

echo -n "Test 2.1 - arborescence limitée sans doublon........................ "
arbo_simple $TMP.d
$PROG $TMP.d > $TMP.out 2> $TMP.err	|| fail "sortie en erreur"
est_vide $TMP.out			|| fail "sortie standard non vide"
est_vide $TMP.err			|| fail "sortie d'erreur non vide"
echo OK

echo -n "Test 2.2 - arborescence limitée avec un seul doublon................ "
# créer un doublon sur l'arborescence précédente
cp $TMP.d/a.11 $TMP.d/doublon-a.11
$PROG $TMP.d > $TMP.out 2> $TMP.err	|| fail "sortie en erreur"
est_vide $TMP.err			|| fail "sortie d'erreur non vide"
ATTENDU="$TMP.d/a.11 $TMP.d/doublon-a.11 =
"
comparer_doublons $TMP.out "$ATTENDU"
echo OK

echo -n "Test 2.3 - arborescence limitée avec deux doublons et un triplon.... "
# ajouter à l'arborescence précédente :
cp $TMP.d/a.11 $TMP.d/triplon-a.11	# le triplon
cp $TMP.d/c.11 $TMP.d/doublon-c.11	# un premier doublon
cp $TMP.d/b.5  $TMP.d/doublon-b.5	# un deuxième doublon
$PROG $TMP.d > $TMP.out 2> $TMP.err	|| fail "sortie en erreur"
est_vide $TMP.err			|| fail "sortie d'erreur non vide"
ATTENDU="$TMP.d/a.11 $TMP.d/doublon-a.11 $TMP.d/triplon-a.11 =
$TMP.d/b.5 $TMP.d/doublon-b.5 =
$TMP.d/c.11 $TMP.d/doublon-c.11 =
"
comparer_doublons $TMP.out "$ATTENDU"
echo OK

echo -n "Test 2.4 - arborescence limitée avec permissions différentes........ "
# ajouter à l'arborescence précédente :
chmod 666 $TMP.d/triplon-a.11		# une différence dans le triplon
chmod 666 $TMP.d/c.11			# une différence dans le premier doublon
$PROG $TMP.d > $TMP.out 2> $TMP.err	|| fail "sortie en erreur"
est_vide $TMP.err			|| fail "sortie d'erreur non vide"
ATTENDU="$TMP.d/a.11 $TMP.d/doublon-a.11 $TMP.d/triplon-a.11 *
$TMP.d/b.5 $TMP.d/doublon-b.5 =
$TMP.d/c.11 $TMP.d/doublon-c.11 *
"
comparer_doublons $TMP.out "$ATTENDU"
echo OK

echo -n "Test 2.5 - test des permissions sur 9 bits seulement................ "
# réinitialiser les permissions de tous les fichiers
find $TMP.d -type f | xargs chmod 666
chmod 1666 $TMP.d/triplon-a.11		# différence à ignorer dans le triplon
$PROG $TMP.d > $TMP.out 2> $TMP.err	|| fail "sortie en erreur"
est_vide $TMP.err			|| fail "sortie d'erreur non vide"
ATTENDU="$TMP.d/a.11 $TMP.d/doublon-a.11 $TMP.d/triplon-a.11 =
$TMP.d/b.5 $TMP.d/doublon-b.5 =
$TMP.d/c.11 $TMP.d/doublon-c.11 =
"
comparer_doublons $TMP.out "$ATTENDU"
echo OK

##############################################################################
# Tests avec des arborescences complexes

nettoyer

echo -n "Test 3.1 - arborescence complexe sans doublon....................... "
arbo_complexe $TMP.d
$PROG $TMP.d > $TMP.out 2> $TMP.err	|| fail "sortie en erreur"
est_vide $TMP.out			|| fail "sortie standard non vide"
est_vide $TMP.err			|| fail "sortie d'erreur non vide"
echo OK

echo -n "Test 3.2 - arborescence complexe avec deux doublons et un triplon... "
cp $TMP.d/x/t/u/a.11   $TMP.d/y/doublon-a.11
cp $TMP.d/x/t/u/a.11   $TMP.d/z/t/triplon-a.11
cp $TMP.d/y/t/c.5      $TMP.d/x/doublon-c.5
cp $TMP.d/z/t/u/v/b.11 $TMP.d/z/doublon-b.11
$PROG $TMP.d > $TMP.out 2> $TMP.err	|| fail "sortie en erreur"
est_vide $TMP.err			|| fail "sortie d'erreur non vide"
ATTENDU="$TMP.d/x/t/u/a.11 $TMP.d/y/doublon-a.11 $TMP.d/z/t/triplon-a.11 =
$TMP.d/y/t/c.5 $TMP.d/x/doublon-c.5 =
$TMP.d/z/t/u/v/b.11 $TMP.d/z/doublon-b.11 =
"
comparer_doublons $TMP.out "$ATTENDU"
echo OK

echo -n "Test 3.3 - arborescence complexe avec permissions................... "
cp $TMP.d/x/t/u/a.11   $TMP.d/y/doublon-a.11
cp $TMP.d/x/t/u/a.11   $TMP.d/z/t/triplon-a.11
cp $TMP.d/y/t/c.5      $TMP.d/x/doublon-c.5
cp $TMP.d/z/t/u/v/b.11 $TMP.d/z/doublon-b.11
find $TMP.d -type f | xargs chmod 666
chmod 600 $TMP.d/y/doublon-a.11
chmod 1666 $TMP.d/x/doublon-c.5
chmod 600 $TMP.d/z/t/u/v/b.11
$PROG $TMP.d > $TMP.out 2> $TMP.err	|| fail "sortie en erreur"
est_vide $TMP.err			|| fail "sortie d'erreur non vide"
ATTENDU="$TMP.d/x/t/u/a.11 $TMP.d/y/doublon-a.11 $TMP.d/z/t/triplon-a.11 *
$TMP.d/y/t/c.5 $TMP.d/x/doublon-c.5 =
$TMP.d/z/t/u/v/b.11 $TMP.d/z/doublon-b.11 *
"
comparer_doublons $TMP.out "$ATTENDU"
echo OK

##############################################################################
# Tests avec des pièges potentiels à prendre en compte

echo -n "Test 4.1 - légère différence à l'octet 8191......................... "
rm -rf $TMP.*
mkdir $TMP.d
base=$TMP.d/base
dd if=/dev/urandom bs=8191 count=1 of=$base 2> /dev/null
(cat $base ; echo -n a) > $base.8191-a
(cat $base ; echo -n b) > $base.8191-b
$PROG $TMP.d > $TMP.out 2> $TMP.err	|| fail "sortie en erreur"
est_vide $TMP.out			|| fail "sortie standard non vide"
est_vide $TMP.err			|| fail "sortie d'erreur non vide"
echo OK

echo -n "Test 4.2 - légère différence à l'octet 8192......................... "
rm -rf $TMP.*
mkdir $TMP.d
base=$TMP.d/base
dd if=/dev/urandom bs=8192 count=1 of=$base 2> /dev/null
(cat $base ; echo -n a) > $base.8192-a
(cat $base ; echo -n b) > $base.8192-b
$PROG $TMP.d > $TMP.out 2> $TMP.err	|| fail "sortie en erreur"
est_vide $TMP.out			|| fail "sortie standard non vide"
est_vide $TMP.err			|| fail "sortie d'erreur non vide"
echo OK

echo -n "Test 4.3 - arborescence avec un faux doublon (lien symbolique)...... "
rm -rf $TMP.*
arbo_simple $TMP.d
# il faut ignorer les liens symboliques
ln -s $TMP.d/a.11  $TMP.d/doublon-a.11		# faux doublon
$PROG $TMP.d > $TMP.out 2> $TMP.err	|| fail "sortie en erreur"
est_vide $TMP.out			|| fail "sortie standard non vide"
est_vide $TMP.err			|| fail "sortie d'erreur non vide"
echo OK

echo -n "Test 4.4 - arborescence avec un lien symbolique erroné.............. "
rm -rf $TMP.*
mkdir $TMP.d
ln -s $TMP.d/toto $TMP.d/inexistant
$PROG $TMP.d > $TMP.out 2> $TMP.err	|| fail "sortie en erreur"
est_vide $TMP.out			|| fail "sortie standard non vide"
est_vide $TMP.err			|| fail "sortie d'erreur non vide"
echo OK

echo -n "Test 4.5 - arborescence avec des chemins <= 512 caractères.......... "
rm -rf $TMP.*
mkdir $TMP.d
LIMITE=512
d=$TMP.d
l=$(echo -n $d | wc -c)
while [ $l -le 500 ]
do
    d=$d/1234567890
    l=$((l+11))
done
mkdir -p $d
n=$((512-l-1))
last=$(echo xxxxxxxxxxxxxxxx | cut -c 1-$((n-1)) )
base=$d/${last}
dd if=/dev/urandom bs=49999 count=1 of=${base}a 2> /dev/null
dd if=/dev/urandom bs=49999 count=1 of=${base}b 2> /dev/null
dd if=/dev/urandom bs=49999 count=1 of=${base}c 2> /dev/null
cp ${base}b ${base}d
$PROG $TMP.d > $TMP.out 2> $TMP.err	|| fail "sortie en erreur"
est_vide $TMP.err			|| fail "sortie d'erreur non vide"
ATTENDU="${base}b ${base}d =
"
comparer_doublons $TMP.out "$ATTENDU"
echo OK

echo -n "Test 4.6 - arborescence avec des chemins de 513 caractères.......... "
base=${base}y
dd if=/dev/urandom bs=49999 count=1 of=${base}a 2> /dev/null
dd if=/dev/urandom bs=49999 count=1 of=${base}b 2> /dev/null
dd if=/dev/urandom bs=49999 count=1 of=${base}c 2> /dev/null
cp ${base}b ${base}d
$PROG $TMP.d > $TMP.out 2> $TMP.err	&& fail "réussite avec chemin > 512 o"
est_vide $TMP.err			&& fail "pas de msg d'erreur"
echo OK

##############################################################################
# Tests de prise en compte des erreurs

nettoyer 

echo -n "Test 5.1 - valgrind................................................. "
arbo_complexe $TMP.d
valgrind --leak-check=full --error-exitcode=10 -q \
	$PROG $TMP.d > $TMP.out 2> $TMP.err \
	|| fail "échec avec valgrind, voir $TMP.err"
est_vide $TMP.err			|| fail "sortie d'erreur non vide"
est_vide $TMP.out			|| fail "sortie standard non vide"
echo OK

echo -n "Test 5.2 - erreur avec open......................................... "
# on repart de l'arborescence complexe
chmod u-r $TMP.d/y/t/c.11
$PROG $TMP.d > $TMP.out 2> $TMP.err	&& fail "open : pas de test d'err ?"
est_vide $TMP.err			&& fail "sortie d'erreur vide"
est_vide $TMP.out			|| fail "sortie standard non vide"
chmod u+r $TMP.d/y/t/c.11
echo OK

echo -n "Test 5.3 - erreur avec opendir...................................... "
# on repart de l'arborescence complexe
chmod u-r $TMP.d/y/t
$PROG $TMP.d > $TMP.out 2> $TMP.err	&& fail "opendir : pas de test d'err ?"
est_vide $TMP.err			&& fail "sortie d'erreur vide"
est_vide $TMP.out			|| fail "sortie standard non vide"
chmod u+r $TMP.d/y/t
echo OK

if [ "$(uname -s)" != Linux ]
then
    echo "Les tests suivants ne peuvent être exécutés que sur Linux"
    exit 1
fi

echo -n "Test 5.4 - erreur avec readdir...................................... "
# on repart de l'arborescence complexe
lancer_faux readdir \
	$PROG $TMP.d > $TMP.out 2> $TMP.err \
					&& fail "readdir : pas de test d'err ?"
est_vide $TMP.err			&& fail "sortie d'erreur vide"
est_vide $TMP.out			|| fail "sortie standard non vide"
echo OK

echo -n "Test 5.5 - erreur avec closedir..................................... "
# on repart de l'arborescence complexe
lancer_faux closedir \
	$PROG $TMP.d > $TMP.out 2> $TMP.err \
					&& fail "closedir : pas de test d'err ?"
est_vide $TMP.err			&& fail "sortie d'erreur vide"
est_vide $TMP.out			|| fail "sortie standard non vide"
echo OK

echo -n "Test 5.6 - erreur avec read......................................... "
# on repart de l'arborescence complexe
lancer_faux read \
	$PROG $TMP.d > $TMP.out 2> $TMP.err \
					&& fail "read : pas de test d'err ?"
est_vide $TMP.err			&& fail "sortie d'erreur vide"
est_vide $TMP.out			|| fail "sortie standard non vide"
echo OK

##############################################################################
# Fini !

nettoyer
echo "Tests ok"
exit 0
