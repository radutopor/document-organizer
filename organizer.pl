#!/usr/bin/perl

use warnings;

use LWP::Simple;
use File::Copy;

#
# FileLoader
#

sub loadFile
{
  (my $file) = @_;
  
  open(FILE_HANDLE, "<", $file);
  
  my $line;
  my $wholeFile;
  
  while ($line = <FILE_HANDLE>)
  {
    $wholeFile = $wholeFile . $line;
  }
  
  return $wholeFile;
}

#
# Splitter
#

sub splitPhrases
{
  (my $text) = @_;

  my @rawPhrases = split(/[.;!?\n]/, $text);
  
  my $rawPhrase;
  my @phrases;
  
  foreach $rawPhrase (@rawPhrases)
  {
    $rawPhrase =~ s/(^\s+)|(\s+$)//g;
    
    if ($rawPhrase ne "")
    {
      my $sanitizedPhrase = lc($rawPhrase);
      
      @phrases = (@phrases, $sanitizedPhrase);
    }
  }
  
  return @phrases;
}

sub splitFilePhrases
{
  (my $file) = @_;
  
  my $fileContents = loadFile($file);
  my @filePhrases = splitPhrases($fileContents);
  
  return @filePhrases;
}

#
# SemanticAnalyser
#

$PHRASE_ONE_MARKER = "`PHRASE_ONE`";
$PHRASE_TWO_MARKER = "`PHRASE_TWO`";
$STS_API_URL = "http://swoogle.umbc.edu/StsService/GetStsSim?operation=api&phrase1=" . $PHRASE_ONE_MARKER . "&phrase2=" . $PHRASE_TWO_MARKER;

sub scorePhrases
{
  (my $phraseOne, my $phraseTwo) = @_;
  
  my $url = $STS_API_URL;
  $url =~ s/$PHRASE_ONE_MARKER/$phraseOne/;
  $url =~ s/$PHRASE_TWO_MARKER/$phraseTwo/;
  
  my $score = get($url);
  
  return $score;
}

$TITLE_ONE_MARKER = "`TITLE_ONE`";
$TITLE_TWO_MARKER = "`TITLE_TWO`";
$SIM_CON_GIGA_API_URL = "http://swoogle.umbc.edu/SimService/GetSimilarity?operation=api&phrase1=" . $TITLE_ONE_MARKER . "&phrase2=" . $TITLE_TWO_MARKER . "&type=concept&corpus=gigawords";
$SIM_REL_GIGA_API_URL = "http://swoogle.umbc.edu/SimService/GetSimilarity?operation=api&phrase1=" . $TITLE_ONE_MARKER . "&phrase2=" . $TITLE_TWO_MARKER . "&type=relation&corpus=gigawords";
$SIM_CON_WEBB_API_URL = "http://swoogle.umbc.edu/SimService/GetSimilarity?operation=api&phrase1=" . $TITLE_ONE_MARKER . "&phrase2=" . $TITLE_TWO_MARKER . "&type=concept&corpus=webbase";
$SIM_REL_WEBB_API_URL = "http://swoogle.umbc.edu/SimService/GetSimilarity?operation=api&phrase1=" . $TITLE_ONE_MARKER . "&phrase2=" . $TITLE_TWO_MARKER . "&type=relation&corpus=webbase";

sub scoreTitles
{
  (my $titleOne, my $titleTwo) = @_;

  my $totalScore = 0;

  my $conceptGigawordsUrl = $SIM_CON_GIGA_API_URL;
  $conceptGigawordsUrl =~ s/$TITLE_ONE_MARKER/$titleOne/;
  $conceptGigawordsUrl =~ s/$TITLE_TWO_MARKER/$titleTwo/;
  
  my $conceptGigawordsScore = get($conceptGigawordsUrl);
  $totalScore += $conceptGigawordsScore;

  my $relationGigawordsUrl = $SIM_REL_GIGA_API_URL;
  $relationGigawordsUrl =~ s/$TITLE_ONE_MARKER/$titleOne/;
  $relationGigawordsUrl =~ s/$TITLE_TWO_MARKER/$titleTwo/;
  
  my $relationGigawordsScore = get($relationGigawordsUrl);
  $totalScore += $relationGigawordsScore;

  my $conceptWebBaseUrl = $SIM_CON_WEBB_API_URL;
  $conceptWebBaseUrl =~ s/$TITLE_ONE_MARKER/$titleOne/;
  $conceptWebBaseUrl =~ s/$TITLE_TWO_MARKER/$titleTwo/;
  
  my $conceptWebBaseScore = get($conceptWebBaseUrl);
  $totalScore += $conceptWebBaseScore;

  my $relationWebBaseUrl = $SIM_REL_WEBB_API_URL;
  $relationWebBaseUrl =~ s/$TITLE_ONE_MARKER/$titleOne/;
  $relationWebBaseUrl =~ s/$TITLE_TWO_MARKER/$titleTwo/;
  
  my $relationWebBaseScore = get($relationWebBaseUrl);
  $totalScore += $relationWebBaseScore;

  my $averageScore = $totalScore / 4;

  return $averageScore;
}

#
# FileAnalyser
#

$NULL_PAIR_WEIGHT = 0.5;
$LENGTH_BONUS_WEIGHT = 0.01;

sub analyseContent
{
  (my $phrasesOneRef, my $phrasesTwoRef) = @_;
  my @phrasesOne = @$phrasesOneRef;
  my @phrasesTwo = @$phrasesTwoRef;
  
  my $pairScore;
  my $nullPairScoreCount = 0;
  my $totalScore = 0;
  
  my $phraseOne;
  my $phraseTwo;
  
  foreach $phraseOne (@phrasesOne)
  {
    foreach $phraseTwo (@phrasesTwo)
    {
      $pairScore = scorePhrases($phraseOne, $phraseTwo);
      
      if ($pairScore == 0)
      {
        $nullPairScoreCount++;
      }
      
      $totalScore += $pairScore;
    }
  }
  
  my $numPhrasesOne = @phrasesOne;
  my $numPhrasesTwo = @phrasesTwo;
  my $totalPairs = $numPhrasesOne * $numPhrasesTwo;
  
  my $averageFactor = $totalPairs - ($nullPairScoreCount * $NULL_PAIR_WEIGHT);
  
  my $averageScore = $totalScore / $averageFactor;
  
  my $lengthScoreBonus = ($totalPairs * $averageScore) * $LENGTH_BONUS_WEIGHT;
  
  my $finalScore = $averageScore + $lengthScoreBonus;
  
  return $finalScore;
}

sub analyseTitles
{
  (my $phrasesOneRef, my $phrasesTwoRef) = @_;
  my @phrasesOne = @$phrasesOneRef;
  my @phrasesTwo = @$phrasesTwoRef;
  
  my $keyPhraseOne = $phrasesOne[0];
  my $titleOne = "0";
  
  #if ($keyPhraseOne =~ /\n$/)
  #{
    $titleOne = $keyPhraseOne;
  #}
  
  my $keyPhraseTwo = $phrasesTwo[0];
  my $titleTwo = "0";
  
  #if ($keyPhraseTwo =~ /\n$/)
  #{
    $titleTwo = $keyPhraseTwo;
  #}
  
  if (($titleOne ne "0") && ($titleTwo ne "0"))
  {
    my $titleScore = scoreTitles($titleOne, $titleTwo);
    
    return $titleScore;
  }
  else
  {
    return -1;
  }
}

$CONTENT_WEIGHT = 0.75;
$TITLE_WEIGHT = 0.25;

sub analyseFiles
{
  (my $fileOne, my $fileTwo) = @_;
  
  my @phrasesOne = splitFilePhrases($fileOne);
  my @phrasesTwo = splitFilePhrases($fileTwo);
  
  my $phrasesOneRef =\ @phrasesOne;
  my $phrasesTwoRef =\ @phrasesTwo;
  
  my $contentScore = analyseContent($phrasesOneRef, $phrasesTwoRef);

  my $titleScore = analyseTitles($phrasesOneRef, $phrasesTwoRef);

  my $aggregateScore;
  
  if ($titleScore != -1)
  {
    my $normalizedContentScore = $contentScore * $CONTENT_WEIGHT;
    my $normalizedTitleScore = $titleScore * $TITLE_WEIGHT;
    
    $aggregateScore = $normalizedContentScore + $normalizedTitleScore;
  }
  else
  {
    $aggregateScore = $contentScore;
  }
  
  return $aggregateScore;
}

#
# DocumentOrganizer
#

$LIKENESS_THRESHOLD = 0.1;

$dir = $ARGV[0];
chdir($dir);

opendir(DIR, $dir);
my @files;
my $file;
while ($file = readdir(DIR))
{
	if ($file =~ /\w/)
	{
		@files = (@files, $file);
	}
}
closedir(DIR);

my %filesDirs = ();

my $likenessScore;
my $category = 0;

my $fileOne;
my $fileTwo;

foreach $fileOne (@files)
{
	foreach $fileTwo (@files)
	{
		if ($fileOne ne $fileTwo)
		{
			$likenessScore = analyseFiles($fileOne, $fileTwo);
			if ($likenessScore >= $LIKENESS_THRESHOLD)
			{
				if (exists($filesDirs{$fileOne}))
				{
					copy($fileTwo, $filesDirs{$fileOne} . "/" . $fileTwo);
				}
				elsif (exists($filesDirs{$fileTwo}))
				{
					copy($fileOne, $filesDirs{$fileTwo} . "/" . $fileOne);
				}
				else
				{
					$category++;
					$newDir = "category" . $category;
					
					mkdir($newDir);
					copy($fileOne, $newDir . "/" . $fileOne);
					copy($fileTwo, $newDir . "/" . $fileTwo);
					
					$filesDirs{$fileOne} = $newDir;
					$filesDirs{$fileTwo} = $newDir;
				}
			}
		}
	}
}