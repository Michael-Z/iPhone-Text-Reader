// RTF parser declarations

//int ecRtfParse(FILE *fp);
int ecRtfParse(RTFDOC *fp);
int ecPushRtfState(void);
int ecPopRtfState(void);
//int ecParseRtfKeyword(FILE *fp);
int ecParseRtfKeyword(RTFDOC *fp);
// int ecParseChar(int c);
int ecParseChar(int ch, RTFDOC *fp);
// int ecTranslateKeyword(char *szKeyword, int param, bool fParam);
int ecTranslateKeyword(char *szKeyword, int param, bool fParam, RTFDOC * fp);
// int ecPrintChar(int ch);
int ecPrintChar(int ch, RTFDOC *fp, bool flush);
int ecEndGroupAction(RDS rds);
int ecApplyPropChange(IPROP iprop, int val);
int ecChangeDest(IDEST idest);
int ecParseSpecialKeyword(IPFN ipfn);
int ecParseSpecialProperty(IPROP iprop, int val);
int ecParseHexByte(void);

// RTF variable declarations

extern int cGroup;
extern RDS rds;
extern RIS ris;

extern CHP chp;
extern PAP pap;
extern SEP sep;
extern DOP dop;

extern SAVE *psave;
extern long cbBin;
extern long lParam;
extern bool fSkipDestIfUnk;
extern FILE *fpIn;

// RTF parser error codes

#define ecOK 0                      // Everything's fine!
#define ecStackUnderflow    1       // Unmatched '}'
#define ecStackOverflow     2       // Too many '{' -- memory exhausted
#define ecUnmatchedBrace    3       // RTF ended during an open group.
#define ecInvalidHex        4       // invalid hex character found in data
#define ecBadTable          5       // RTF table (sym or prop) invalid
#define ecAssertion         6       // Assertion failure
#define ecEndOfFile         7       // End of file reached while reading RTF
