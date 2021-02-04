<?php

class Vpstraffic extends Lxdb
{

    //Core

    //Data
    static $__desc =  array("", "",  "traffic_history");
    static $__desc_nname =  array("", "",  "device_name");
    static $__desc_parent_name =  array("", "",  "device_name");
    static $__desc_month    =   array("", "",  "month");
    static $__desc_traffic_usage     =  array("", "",  "total_(mb)");

    //Objects

    function isSync()
    {
        return false;
    }
}
