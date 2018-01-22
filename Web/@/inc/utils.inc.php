<?

require __DIR__ . '/../SourceQuery/bootstrap.php';
use xPaw\SourceQuery\SourceQuery;

function LogMessage($message)
{
    $fp = fopen( __DIR__ . "/errorlog.php", "a+");
    fputs($fp, "<?PHP exit;?>    ");
    fputs($fp, $message);
    fputs($fp, "\n");
    fclose($fp);
}

function QuerySRCDSInfo($srvAdr)
{
    $Query = new SourceQuery();
    $address = explode(':', $srvAdr, 2);

    try
    {
        $Query->Connect($address[0], (int)$address[1], 1, SourceQuery::SOURCE);
        return $Query->GetInfo();

    }
    catch( Exception $ex)
    {
        LogMessage($ex->getMessage());
    }
    finally
    {
        $Query->Disconnect( );
    }
    return null;
}

?>