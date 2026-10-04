/* Linked into programs with -Wl,--wrap=__imp_setlocale and
   -Wl,--wrap=__imp__wsetlocale (config.site): their setlocale and
   _wsetlocale calls go through these pointers, which give the UCRT's
   functions POSIX behavior:

   setlocale (CATEGORY, "") takes the locale from LC_ALL, LC_<CATEGORY> or
   LANG, the first one set, and is "C" if none is; the UCRT's looks at the
   Windows settings instead (decimal comma, local month names).

   Names of the C locale the UCRT rejects are mapped: "POSIX" is "C", and
   "C.UTF-8" ("C.utf8") is C with UTF-8 characters, as glibc's: "C" for
   every category but LC_CTYPE, which gets the UCRT's ".UTF-8".  rattler-
   build sets LC_ALL=C.UTF-8.  Other names go to the UCRT as given; it also
   understands names such as "de_DE.UTF-8".  */
#include <locale.h>
#include <stdlib.h>
#include <string.h>
#include <wchar.h>

/* The UCRT's functions, as --wrap names their import pointers.  */
extern char *(*__real___imp_setlocale) (int, const char *);
extern wchar_t *(*__real___imp__wsetlocale) (int, const wchar_t *);
#define real_setlocale (*__real___imp_setlocale)
#define real_wsetlocale (*__real___imp__wsetlocale)

static const struct
{
  int category;
  const char *name;
} categories[] =
{
  { LC_COLLATE, "LC_COLLATE" },
  { LC_CTYPE, "LC_CTYPE" },
  { LC_MONETARY, "LC_MONETARY" },
  { LC_NUMERIC, "LC_NUMERIC" },
  { LC_TIME, "LC_TIME" },
};

/* The locale the environment gives CATEGORY (not LC_ALL).  */
static const char *
env_locale (int category)
{
  const char *s;
  size_t i;

  if ((s = getenv ("LC_ALL")) && *s)
    return s;
  for (i = 0; i < sizeof categories / sizeof *categories; i++)
    if (categories[i].category == category)
      {
        if ((s = getenv (categories[i].name)) && *s)
          return s;
        break;
      }
  if ((s = getenv ("LANG")) && *s)
    return s;
  return "C";
}

/* Set CATEGORY to the locale named LOCALE (not "").  */
static char *
set_named (int category, const char *locale)
{
  if (!strcmp (locale, "POSIX"))
    locale = "C";
  else if (!strcmp (locale, "C.UTF-8") || !strcmp (locale, "C.utf8"))
    {
      if (category == LC_CTYPE)
        return real_setlocale (LC_CTYPE, ".UTF-8");
      if (category != LC_ALL)
        return real_setlocale (category, "C");
      if (!real_setlocale (LC_ALL, "C") || !real_setlocale (LC_CTYPE, ".UTF-8"))
        return NULL;
      return real_setlocale (LC_ALL, NULL);
    }
  return real_setlocale (category, locale);
}

static char *
posix_setlocale (int category, const char *locale)
{
  char *saved;
  size_t i;

  if (!locale)
    return real_setlocale (category, NULL);
  if (*locale)
    return set_named (category, locale);
  if (category != LC_ALL)
    return set_named (category, env_locale (category));

  /* Each category from its own variables.  If one fails, the locale
     stays as it was, and the result is NULL.  */
  saved = strdup (real_setlocale (LC_ALL, NULL));
  for (i = 0; i < sizeof categories / sizeof *categories; i++)
    if (!set_named (categories[i].category,
                    env_locale (categories[i].category)))
      {
        if (saved)
          real_setlocale (LC_ALL, saved);
        free (saved);
        return NULL;
      }
  free (saved);
  return real_setlocale (LC_ALL, NULL);
}

/* Locale names are ASCII: through the narrow function, answered in wide
   form.  */
static wchar_t *
posix_wsetlocale (int category, const wchar_t *wlocale)
{
  char locale[64];
  size_t i;

  if (!wlocale)
    return real_wsetlocale (category, NULL);
  for (i = 0; wlocale[i] && wlocale[i] < 0x80 && i < sizeof locale - 1; i++)
    locale[i] = (char) wlocale[i];
  if (wlocale[i])
    return real_wsetlocale (category, wlocale);
  locale[i] = '\0';
  if (!posix_setlocale (category, locale))
    return NULL;
  return real_wsetlocale (category, NULL);
}

char *(*__wrap___imp_setlocale) (int, const char *) = posix_setlocale;
wchar_t *(*__wrap___imp__wsetlocale) (int, const wchar_t *) = posix_wsetlocale;
