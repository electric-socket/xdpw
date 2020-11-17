// XD Pascal for Windows (XPDW) - a 32-bit compiler
// Copyright (c) 2009-2010, 2019-2020, Vasiliy Tereshkov

// Latest upgrade by Paul Robinson:  Friday, November 6, 2020

// VERSION 0.14.2

// Routines related to listing the source of the program

unit Listing;

interface

uses
  Common,SysUtils;

var
  StartTime,
  EndTime: TSystemTime;
  ListingFile: Text;


  Procedure EolListing;
  Procedure WriteListing(Ch:Char);
  Procedure StopListing;
  Procedure StartListing;
  Procedure InitListing;

implementation

Procedure EOLListing;
Begin
    ListingLine := ListingLine+1;
    ListingPageLine := ListingPageLine+1 ;
    if ListingPageLine >60 then
    begin
        // TODO: Close prior page
      ListingPageLine :=1 ;
        // TODO: write new page
        ListingPage :=  ListingPage +1;
        // TODO: write header
        // TODO: Write Subtitle
    end;

  //  writeln(ListingFile);

end;

Procedure WriteListing(Ch:Char);
Begin

end;

Procedure InitListing;
Begin
  ListingLine := 1;
  ListingPage := 1;
  ListingPos  := 0;
  ListingPageLine :=1;
  ListingProcLevelOpen  := 0;
  ListingProcLevelClose  := 0;
  ListingBlockLevelOpen  := 0;
  ListingBlockLevelClose := 0;

end;

// suspend further output to listing file
procedure StopListing;
begin

end;

// resume generating listings
Procedure StartListing;
begin

end;

end.


