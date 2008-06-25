

#import "textReader.h"

#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>
#include "rtftype.h"
#include "rtfdecl.h"



int cGroup;
bool fSkipDestIfUnk;
long cbBin;
long lParam;

RDS rds;
RIS ris;

CHP chp;
PAP pap;
SEP sep;
DOP dop;

SAVE *psave;

//
// %%Function: ecRtfParse
//
// Step 1:
// Isolate RTF keywords and send them to ecParseRtfKeyword;
// Push and pop state at the start and end of RTF groups;
// Send text to ecParseChar for further processing.
//


// --------------------------------------------------------

int rtfGetc(RTFDOC * rtfdoc)
{
    unsigned char ch = 0x00;
    
    if (rtfdoc->ungetbufL > 0)
        return (int)rtfdoc->ungetbuf[--rtfdoc->ungetbufL];
    
    if (rtfdoc->pos >= [rtfdoc->src length])
        return EOF;
        
    NSRange range = {rtfdoc->pos, 1};
    [rtfdoc->src getBytes:&ch range:range];
    
    rtfdoc->pos++;
    
    return (int)ch;
    
} // rtfGetc 


int rtfUngetc(int ch, RTFDOC * rtfdoc)
{
    if (rtfdoc->ungetbufL >= sizeof(rtfdoc->ungetbuf)/sizeof(*rtfdoc->ungetbuf))
        return EOF;
    
    rtfdoc->ungetbuf[rtfdoc->ungetbufL++] = (unsigned char)ch;
    
    return ch;
} // rtfUngetc

// --------------------------------------------------------


int
// ecRtfParse(FILE *fp)
ecRtfParse(RTFDOC * fp)
{
    int ch;
    int ec;
    int cNibble = 2;
    int b = 0;
    
    // while ((ch = getc(fp)) != EOF)
    while ((ch = rtfGetc(fp)) != EOF)
    {
        if (cGroup < 0)
            return ecStackUnderflow;
        if (ris == risBin)                      // if we're parsing binary data, handle it directly
        {
            if ((ec = ecParseChar(ch, fp)) != ecOK)
                return ec;
        }
        else
        {
            switch (ch)
            {
            case '{':
                if ((ec = ecPushRtfState()) != ecOK)
                    return ec;
                break;
            case '}':
                if ((ec = ecPopRtfState()) != ecOK)
                    return ec;
                break;
            case '\\':
                if ((ec = ecParseRtfKeyword(fp)) != ecOK)
                    return ec;
                break;
            case 0x0d:
            case 0x0a:          // cr and lf are noise characters...
                break;
            default:
                if (ris == risNorm)
                {
                    if ((ec = ecParseChar(ch, fp)) != ecOK)
                        return ec;
                }
                else
                {               // parsing hex data
                    if (ris != risHex)
                        return ecAssertion;
                    b = b << 4;
                    if (isdigit(ch))
                        b += (char) ch - '0';
                    else
                    {
                        if (islower(ch))
                        {
                            if (ch < 'a' || ch > 'f')
                                return ecInvalidHex;
                            b += 0x0a + (char) ch - 'a';
                        }
                        else
                        {
                            if (ch < 'A' || ch > 'F')
                                return ecInvalidHex;
                            b += 0x0A + (char) ch - 'A';
                        }
                    }
                    cNibble--;
                    if (!cNibble)
                    {
                        if ((ec = ecParseChar(b, fp)) != ecOK)
                            return ec;
                        cNibble = 2;
                        b = 0;
                        ris = risNorm;
                    }
                }                   // end else (ris != risNorm)
                break;
            }       // switch
        }           // else (ris != risBin)
    }               // while
    
    ecPrintChar('\n', fp, true);
    
    if (cGroup < 0)
        return ecStackUnderflow;
    if (cGroup > 0)
        return ecUnmatchedBrace;
    return ecOK;
}

//
// %%Function: ecPushRtfState
//
// Save relevant info on a linked list of SAVE structures.
//

int
ecPushRtfState(void)
{
    SAVE *psaveNew = (SAVE *)malloc(sizeof(SAVE));
    if (!psaveNew)
        return ecStackOverflow;

    psaveNew -> pNext = psave;
    psaveNew -> chp = chp;
    psaveNew -> pap = pap;
    psaveNew -> sep = sep;
    psaveNew -> dop = dop;
    psaveNew -> rds = rds;
    psaveNew -> ris = ris;
    ris = risNorm;
    psave = psaveNew;
    cGroup++;
    return ecOK;
}

//
// %%Function: ecPopRtfState
//
// If we're ending a destination (that is, the destination is changing),
// call ecEndGroupAction.
// Always restore relevant info from the top of the SAVE list.
//

int
ecPopRtfState(void)
{
    SAVE *psaveOld;
    int ec;

    if (!psave)
        return ecStackUnderflow;

    if (rds != psave->rds)
    {
        if ((ec = ecEndGroupAction(rds)) != ecOK)
            return ec;
    }
    chp = psave->chp;
    pap = psave->pap;
    sep = psave->sep;
    dop = psave->dop;
    rds = psave->rds;
    ris = psave->ris;

    psaveOld = psave;
    psave = psave->pNext;
    cGroup--;
    free(psaveOld);
    return ecOK;
}

//
// %%Function: ecParseRtfKeyword
//
// Step 2:
// get a control word (and its associated value) and
// call ecTranslateKeyword to dispatch the control.
//

int
// ecParseRtfKeyword(FILE *fp)
ecParseRtfKeyword(RTFDOC *fp)
{
    int ch;
    bool fParam = fFalse;
    bool fNeg = fFalse;
    int param = 0;
    char *pch;
    char szKeyword[30];
    char szParameter[20];

    szKeyword[0] = '\0';
    szParameter[0] = '\0';
    // if ((ch = getc(fp)) == EOF)
    if ((ch = rtfGetc(fp)) == EOF)
        return ecEndOfFile;
    if (!isalpha(ch))           // a control symbol; no delimiter.
    {
        szKeyword[0] = (char) ch;
        szKeyword[1] = '\0';
        return ecTranslateKeyword(szKeyword, 0, fParam, fp);
    }
    // for (pch = szKeyword; isalpha(ch); ch = getc(fp))
    for (pch = szKeyword; isalpha(ch); ch = rtfGetc(fp))
        *pch++ = (char) ch;
    *pch = '\0';
    if (ch == '-')
    {
        fNeg  = fTrue;
        // if ((ch = getc(fp)) == EOF)
        if ((ch = rtfGetc(fp)) == EOF)
            return ecEndOfFile;
    }
    if (isdigit(ch))
    {
        fParam = fTrue;         // a digit after the control means we have a parameter
        // for (pch = szParameter; isdigit(ch); ch = getc(fp))
        for (pch = szParameter; isdigit(ch); ch = rtfGetc(fp))
            *pch++ = (char) ch;
        *pch = '\0';
        param = atoi(szParameter);
        if (fNeg)
            param = -param;
        lParam = atol(szParameter);
        if (fNeg)
            param = -param;
    }
    if (ch != ' ')
        // ungetc(ch, fp);
        rtfUngetc(ch, fp);
    return ecTranslateKeyword(szKeyword, param, fParam, fp);
}

//
// %%Function: ecParseChar
//
// Route the character to the appropriate destination stream.
//

int
ecParseChar(int ch, RTFDOC *fp)
{
    if (ris == risBin && --cbBin <= 0)
        ris = risNorm;
        
    switch (rds)
    {
    case rdsSkip:
        // Toss this character.
        return ecOK;
        
    case rdsNorm:
        // Output a character. Properties are valid at this point.
        return ecPrintChar(ch, fp, false);   
    
    default:
    // handle other destinations....
        return ecOK;
    }
}

//
// %%Function: ecPrintChar
//
// Send a character to the output file.
//

int
ecPrintChar(int ch, RTFDOC *fp, bool flush)
{   
    fp->c[fp->cL++] = ch;
    if (flush || fp->cL >= sizeof(fp->c)/sizeof(*fp->c))
    {
        // [fp->dest appendFormat:@"%.*S", fp->cL, fp->c];
        [fp->dest appendBytes:&fp->c[0] length:fp->cL];
        fp->cL = 0;
    }
        
    return ecOK;
}


