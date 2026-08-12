const mojibakeReplacements: Array<[string, string]> = [
  ["\u00c3\u0192\u00c2\u00a1", "\u00e1"],
  ["\u00c3\u0192\u00c2\u00a9", "\u00e9"],
  ["\u00c3\u0192\u00c2\u00ad", "\u00ed"],
  ["\u00c3\u0192\u00c2\u00b3", "\u00f3"],
  ["\u00c3\u0192\u00c2\u00ba", "\u00fa"],
  ["\u00c3\u0192\u00c2\u00b1", "\u00f1"],
  ["\u00c3\u0192\u00c2\u00bc", "\u00fc"],
  ["\u00c3\u00a1", "\u00e1"],
  ["\u00c3\u00a9", "\u00e9"],
  ["\u00c3\u00ad", "\u00ed"],
  ["\u00c3\u00b3", "\u00f3"],
  ["\u00c3\u00ba", "\u00fa"],
  ["\u00c3\u00b1", "\u00f1"],
  ["\u00c3\u00bc", "\u00fc"],
  ["\u00c3\u0081", "\u00c1"],
  ["\u00c3\u0089", "\u00c9"],
  ["\u00c3\u008d", "\u00cd"],
  ["\u00c3\u0093", "\u00d3"],
  ["\u00c3\u009a", "\u00da"],
  ["\u00c3\u0091", "\u00d1"],
  ["\u00c2\u00bf", "\u00bf"],
  ["\u00c2\u00a1", "\u00a1"],
  ["\u00c2\u00ba", "\u00ba"],
  ["\u00c2\u00aa", "\u00aa"]
];

const spanishWordReplacements: Array<[RegExp, string]> = [
  [/\bCampana\b/g, "Campa\u00f1a"],
  [/\bcampana\b/g, "campa\u00f1a"],
  [/\bFaccion\b/g, "Facci\u00f3n"],
  [/\bfaccion\b/g, "facci\u00f3n"],
  [/\bTecnologia\b/g, "Tecnolog\u00eda"],
  [/\btecnologia\b/g, "tecnolog\u00eda"],
  [/\bTecnologias\b/g, "Tecnolog\u00edas"],
  [/\btecnologias\b/g, "tecnolog\u00edas"],
  [/\bTecnologico\b/g, "Tecnol\u00f3gico"],
  [/\btecnologico\b/g, "tecnol\u00f3gico"],
  [/\bTecnologica\b/g, "Tecnol\u00f3gica"],
  [/\btecnologica\b/g, "tecnol\u00f3gica"],
  [/\bConstruccion\b/g, "Construcci\u00f3n"],
  [/\bconstruccion\b/g, "construcci\u00f3n"],
  [/\bProduccion\b/g, "Producci\u00f3n"],
  [/\bproduccion\b/g, "producci\u00f3n"],
  [/\bMision\b/g, "Misi\u00f3n"],
  [/\bmision\b/g, "misi\u00f3n"],
  [/\bOperacion\b/g, "Operaci\u00f3n"],
  [/\boperacion\b/g, "operaci\u00f3n"],
  [/\bLimites\b/g, "L\u00edmites"],
  [/\blimites\b/g, "l\u00edmites"],
  [/\bMaximo\b/g, "M\u00e1ximo"],
  [/\bmaximo\b/g, "m\u00e1ximo"],
  [/\bMinimo\b/g, "M\u00ednimo"],
  [/\bminimo\b/g, "m\u00ednimo"],
  [/\bEjercito\b/g, "Ej\u00e9rcito"],
  [/\bejercito\b/g, "ej\u00e9rcito"],
  [/\bArbol\b/g, "\u00c1rbol"],
  [/\barbol\b/g, "\u00e1rbol"],
  [/\bSesion\b/g, "Sesi\u00f3n"],
  [/\bsesion\b/g, "sesi\u00f3n"],
  [/\bConexion\b/g, "Conexi\u00f3n"],
  [/\bconexion\b/g, "conexi\u00f3n"],
  [/\bValido\b/g, "V\u00e1lido"],
  [/\bvalido\b/g, "v\u00e1lido"],
  [/\bValida\b/g, "V\u00e1lida"],
  [/\bvalida\b/g, "v\u00e1lida"],
  [/\bAutomatico\b/g, "Autom\u00e1tico"],
  [/\bautomatico\b/g, "autom\u00e1tico"],
  [/\bAutomatica\b/g, "Autom\u00e1tica"],
  [/\bautomatica\b/g, "autom\u00e1tica"],
  [/\bGalactico\b/g, "Gal\u00e1ctico"],
  [/\bgalactico\b/g, "gal\u00e1ctico"],
  [/\bGalactica\b/g, "Gal\u00e1ctica"],
  [/\bgalactica\b/g, "gal\u00e1ctica"],
  [/\bInformacion\b/g, "Informaci\u00f3n"],
  [/\binformacion\b/g, "informaci\u00f3n"],
  [/\bDescripcion\b/g, "Descripci\u00f3n"],
  [/\bdescripcion\b/g, "descripci\u00f3n"],
  [/\bSeleccion\b/g, "Selecci\u00f3n"],
  [/\bseleccion\b/g, "selecci\u00f3n"],
  [/\bResolucion\b/g, "Resoluci\u00f3n"],
  [/\bresolucion\b/g, "resoluci\u00f3n"],
  [/\bRevision\b/g, "Revisi\u00f3n"],
  [/\brevision\b/g, "revisi\u00f3n"],
  [/\bAccion\b/g, "Acci\u00f3n"],
  [/\baccion\b/g, "acci\u00f3n"],
  [/\bPublico\b/g, "P\u00fablico"],
  [/\bpublico\b/g, "p\u00fablico"],
  [/\bPublica\b/g, "P\u00fablica"],
  [/\bpublica\b/g, "p\u00fablica"],
  [/\bMovil\b/g, "M\u00f3vil"],
  [/\bmovil\b/g, "m\u00f3vil"],
  [/\bPagina\b/g, "P\u00e1gina"],
  [/\bpagina\b/g, "p\u00e1gina"],
  [/\bDias\b/g, "D\u00edas"],
  [/\bdias\b/g, "d\u00edas"],
  [/\bFisica\b/g, "F\u00edsica"],
  [/\bfisica\b/g, "f\u00edsica"],
  [/\bBasico\b/g, "B\u00e1sico"],
  [/\bbasico\b/g, "b\u00e1sico"],
  [/\bBasicos\b/g, "B\u00e1sicos"],
  [/\bbasicos\b/g, "b\u00e1sicos"],
  [/\bTambien\b/g, "Tambi\u00e9n"],
  [/\btambien\b/g, "tambi\u00e9n"],
  [/\bAnadir\b/g, "A\u00f1adir"],
  [/\banadir\b/g, "a\u00f1adir"],
  [/\bPequeno\b/g, "Peque\u00f1o"],
  [/\bpequeno\b/g, "peque\u00f1o"],
  [/\bProximamente\b/g, "Pr\u00f3ximamente"],
  [/\bproximamente\b/g, "pr\u00f3ximamente"],
  [/\bNumero\b/g, "N\u00famero"],
  [/\bnumero\b/g, "n\u00famero"],
  [/\bTactil\b/g, "T\u00e1ctil"],
  [/\btactil\b/g, "t\u00e1ctil"],
  [/\bTitulo\b/g, "T\u00edtulo"],
  [/\btitulo\b/g, "t\u00edtulo"],
  [/\bLineas\b/g, "L\u00edneas"],
  [/\blineas\b/g, "l\u00edneas"],
  [/\bOrbita\b/g, "\u00d3rbita"],
  [/\borbita\b/g, "\u00f3rbita"],
  [/\bEpica\b/g, "\u00c9pica"],
  [/\bepica\b/g, "\u00e9pica"],
  [/\bEpicas\b/g, "\u00c9picas"],
  [/\bepicas\b/g, "\u00e9picas"],
  [/\bHeroe\b/g, "H\u00e9roe"],
  [/\bheroe\b/g, "h\u00e9roe"],
  [/\bCapitan\b/g, "Capit\u00e1n"],
  [/\bcapitan\b/g, "capit\u00e1n"],
  [/\bCampeon\b/g, "Campe\u00f3n"],
  [/\bcampeon\b/g, "campe\u00f3n"],
  [/\bSenor\b/g, "Se\u00f1or"],
  [/\bsenor\b/g, "se\u00f1or"],
  [/\bEstan\b/g, "Est\u00e1n"],
  [/\bestan\b/g, "est\u00e1n"]
];

export function fixSpanishText(value: string) {
  let next = value;

  for (let index = 0; index < 2; index += 1) {
    for (const [search, replacement] of mojibakeReplacements) {
      next = next.split(search).join(replacement);
    }
  }

  for (const [pattern, replacement] of spanishWordReplacements) {
    next = next.replace(pattern, replacement);
  }

  return next;
}

export function fixOptionalSpanishText(value?: string | null) {
  return value ? fixSpanishText(value) : value;
}

export function normalizeSpanishTextKey(value: unknown) {
  return fixSpanishText(String(value ?? ""))
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .trim()
    .toLowerCase();
}
