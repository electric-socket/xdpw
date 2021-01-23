// Check string and character constants

program err005;
const
       Cr          = #13;
       LF          = #10;
       Return      = CR;
       LineFeed    = LF;
       {$Show all,narrow} 
       CRLF        = #13#10;
       Be          = 'Be';
       TextA       = #13'Text';
       TextB       = #13+#10;
       TextC       = #13'Yest'#10;
       TextD       = 'Yes'#13'Yest'#10#13;
       Mixed_Str   = 'A '#13#10'longer String';




begin
{$Show all,narrow}
end.

